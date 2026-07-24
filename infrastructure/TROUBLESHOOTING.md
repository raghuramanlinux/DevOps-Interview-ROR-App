# Deployment troubleshooting log

This is a chronological record of every issue hit getting from `terraform apply`
to a fully healthy, ALB-served application, kept because the fixes are
non-obvious and worth not re-discovering. Each entry: symptom → root cause →
fix.

## 1. RDS: `InvalidParameterCombination: Cannot find version 13.3 for postgres`

**Symptom:** `terraform apply` failed creating the RDS instance.
**Root cause:** the assignment's README specifies Postgres 13.3, but AWS has
since deprecated that exact minor version in this account/region.
**Fix:** queried available versions (`aws rds describe-db-engine-versions
--engine postgres --query "DBEngineVersions[?starts_with(EngineVersion,
`13.`)]"`), picked the latest available 13.x (`13.23`), set via
`db_engine_version` in `terraform.tfvars`. Same major version, so no
compatibility concerns.

## 2. Secrets Manager: `already scheduled for deletion`

**Symptom:** re-running `terraform apply` after a `terraform destroy` failed
creating `aws_secretsmanager_secret.rails_master_key`.
**Root cause:** `terraform destroy` only *schedules* Secrets Manager secret
deletion (30-day recovery window by default); the name stays reserved.
**Fix:** force-deleted the pending secret once via `aws secretsmanager
delete-secret --force-delete-without-recovery`, and set
`recovery_window_in_days = 0` on that resource going forward so future
destroy/recreate cycles don't hit this (a production system managing a
secret that's expensive to lose would keep a positive recovery window
instead).

## 3. GitHub Actions OIDC: `Not authorized to perform sts:AssumeRoleWithWebIdentity` (attempt 1)

**Symptom:** the `Configure AWS credentials via OIDC` step failed immediately,
after 12 silent retries, with no further detail in the Actions log.
**Root cause:** `aws-actions/configure-aws-credentials` attaches IAM role
session tags (repo/workflow/actor/etc.) by default. That requires the trust
policy to allow `sts:TagSession` in addition to
`sts:AssumeRoleWithWebIdentity` — ours only had the latter, so STS denied
the *entire* call, not just the tagging part.
**Fix:** added `"sts:TagSession"` alongside `"sts:AssumeRoleWithWebIdentity"`
in the trust policy's `actions` list (`modules/iam/main.tf`).

## 4. Same OIDC error, still failing after fix #3

**Symptom:** identical error after the TagSession fix.
**Root cause:** diagnosed via CloudTrail (`aws cloudtrail lookup-events
--lookup-attributes AttributeKey=EventName,AttributeValue=AssumeRoleWithWebIdentity`),
which showed the actual `sub` claim GitHub sent:
`repo:raghuramanlinux@12133794/DevOps-Interview-ROR-App@1311424251:ref:refs/heads/main`
— GitHub appends immutable `@<owner_id>`/`@<repo_id>` suffixes (a
rename-hijack protection), not the plain `repo:org/repo:...` form most
examples assume. The trust policy's `StringLike` condition only matched the
plain form.
**Fix:** widened the condition to accept both shapes:
```
values = [
  "repo:${var.github_org}/${var.github_repo}:*",
  "repo:${var.github_org}@*/${var.github_repo}@*:*",
]
```

## 5. Migration task: `CannotPullContainerError: ... not found`

**Symptom:** the one-shot migrate task failed to start; exit code came back
`None` (never actually ran).
**Root cause:** the build/push step tagged images with a short SHA
(`sha-${GITHUB_SHA::12}`), but the task-definition render steps referenced
the full SHA (`sha-${{ github.sha }}`) — two different tag strings, so ECS
tried to pull a tag that had never been pushed.
**Fix:** used the full `$GITHUB_SHA` consistently in both the build/push and
render steps.

## 6. ECR: `tag invalid: ... 'latest' ... cannot be overwritten because the tag is immutable`

**Symptom:** the *next* run's build/push step failed outright.
**Root cause:** the ECR repos are `image_tag_mutability = "IMMUTABLE"` (a
deliberate security choice — sha tags are content-addressable and
traceable). The workflow also pushed a mutable `latest` tag every run, which
an immutable repo rejects on the second push. `latest` was never actually
referenced by any task definition (only `sha-<full sha>` is), so it wasn't
load-bearing.
**Fix:** stopped building/pushing `latest` entirely.

## 7. Same immutable-tag error, still failing after fix #6

**Symptom:** identical error one run later.
**Root cause:** the fix for #6 only removed the `latest` push from the
*rails* build step — a leftover `docker push "$NGINX_REPO:latest"` line
survived in the nginx step (an editing mistake, caught by diffing the raw
file content on GitHub against the intended change).
**Fix:** removed the leftover line.

## 8. `aws ecs wait services-stable`: `Max attempts exceeded`

**Symptom:** deploy step succeeded, but the final wait step timed out.
**Root cause:** `aws ecs describe-services` showed *two* active deployments:
the new one (progressing normally) and a zombie left over from the very
first `terraform apply` — task-def revision `:1`, which referenced
`image_tag = "latest"` (the Terraform variable's bootstrap default, before
any image existed). With no deployment circuit breaker configured, ECS had
been retrying that broken deployment indefinitely (36 failed task
placements and counting) instead of giving up.
**Fix:** added `deployment_circuit_breaker { enable = true, rollback =
true }` to the ECS service so a deployment that can never reach steady
state rolls back automatically instead of retrying forever.

## 9. Rails container `UNHEALTHY` (Docker health check)

**Symptom:** `rails_app`'s ECS container health check never passed;
`nginx` (which depends on it via `dependsOn: HEALTHY`) never started.
**Root cause:** CloudWatch logs showed `ActionDispatch::HostAuthorization
... Blocked hosts: localhost:3000`. The container health check curls
`http://localhost:3000/` directly, but Rails' `config.hosts` only allowed
`ENV['LB_ENDPOINT']` (the ALB DNS name) — so Rails 403'd its own health
check.
**Fix:** added `config.hosts << "localhost"` in `production.rb`. Safe
because that request never leaves the task's own network namespace — it's
not spoofable via the ALB the way an external Host header would be.

## 10. `terraform apply` silently reverted a live deploy back to the broken revision

**Symptom:** applying the circuit-breaker fix (#8) via Terraform caused the
*live* service to snap back to task-def revision `:1` — the original broken
one — undoing what CI had deployed.
**Root cause:** `aws_ecs_service.task_definition` was bound to
`aws_ecs_task_definition.app.arn`. Terraform's state only knows about the
one revision *it* created; CI registers new revisions and calls
`update-service` directly, entirely outside Terraform's view. Every
`terraform apply` therefore fought CI for control and won, reverting to
Terraform's own (stale) revision.
**Fix:** added a `lifecycle { ignore_changes = [task_definition] }` block
to the service. Terraform still owns the *shape* of the task definition
(cpu/memory/env vars/etc.); CI owns which revision is actually live after
the initial bootstrap.

## 11. Migration exit code 1: `ActiveRecord::ProtectedEnvironmentError`

**Symptom:** the migrate task now actually ran (progress from #5) but
exited 1.
**Root cause:** logs showed `You are attempting to run a destructive action
against your 'production' database`. Rails classifies `db:schema:load` as
destructive and refuses to run it against `RAILS_ENV=production` — even on
a brand-new, empty database — unless
`DISABLE_DATABASE_ENVIRONMENT_CHECK=1` is set.
**Fix:** set that env var, scoped to the one-shot migrate task definition
only (the long-running service tasks never run migrations at all, so they
don't need it).

## 12. Deployment circuit breaker fired for real: `tasks failed to start`

**Symptom:** after fix #11, the *new* deployment (built from a genuinely
fixed image) itself failed, rolling back to the old broken revision `:1`
again.
**Root cause:** CloudWatch nginx logs: `nginx: [emerg] host not found in
upstream "rails_app:3000"`. The nginx image is built to work in both
docker-compose (bridge network, containers reachable by name) and ECS
(awsvpc network mode, one shared network namespace per task, sibling
containers reachable only via `localhost`) via an `envsubst`-templated
`RAILS_UPSTREAM` variable — but the ECS task definition never actually set
`RAILS_UPSTREAM=127.0.0.1` on the nginx container, so it kept the image's
docker-compose default (`rails_app`), which doesn't resolve. nginx crashed
immediately; since both containers are `essential`, the whole task stopped.
Notably, Rails itself was fine — its logs showed a real `200 OK` for `/`
moments before nginx's crash killed the task.
**Fix:** added `environment = [{ name = "RAILS_UPSTREAM", value =
"127.0.0.1" }]` to the nginx container definition.

## 13. ECS reported tasks `HEALTHY`, ALB target group still showed them `unhealthy`

**Symptom:** `aws ecs wait services-stable` succeeded and `aws ecs
describe-tasks` showed `rails_app` healthy, but
`describe-target-health` kept returning `unhealthy` /
`Target.ResponseCodeMismatch`, and the ALB itself returned intermittent
503s.
**Root cause:** `describe-target-health --query
'TargetHealthDescriptions[].TargetHealth.Description'` showed `Health
checks failed with these codes: [403]`. ALB target groups with
`target_type = "ip"` send the target's raw private IP as the `Host` header
on health check requests (e.g. `10.0.11.73:80`), not the ALB's DNS name —
a *different* request from the container's own internal Docker health
check (fixed in #9), and also blocked by `HostAuthorization`.
**Fix:** allowlisted the VPC's own CIDR as an `IPAddr` range in
`config.hosts`, threaded through as a `VPC_CIDR` environment variable from
Terraform (`var.vpc_cidr` → ECS module → container env → Rails):
```ruby
if ENV["VPC_CIDR"].present?
  require "ipaddr"
  config.hosts << IPAddr.new(ENV["VPC_CIDR"])
end
```
Scoped to the VPC's private range, not a wildcard-open bypass.

---

## Diagnostic tools that mattered

- **CloudTrail** (`aws cloudtrail lookup-events`) was the only way to see the
  *actual* OIDC subject claim GitHub sent (#4) — the GitHub Actions debug
  log alone wasn't enough.
- **`aws ecs describe-services --query 'services[0].deployments'`** surfaced
  the zombie deployment (#8) that a bare "failed" workflow status hid.
- **CloudWatch Logs** (`aws logs get-log-events`) on the `/ecs/ror-app` log
  group was where every real application-level root cause (#9, #11, #12)
  actually showed up — ECS/ALB-level status alone only said *that*
  something failed, never *why*.
- **`aws elbv2 describe-target-health`**'s `Description` field (not just
  `State`) had the actual HTTP status code the ALB was seeing (#13) — the
  `State: unhealthy` alone wasn't enough to distinguish "app is down" from
  "app is up but rejecting this specific request".
