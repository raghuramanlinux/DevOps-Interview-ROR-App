#!/bin/sh
set -e

echo "bundle installation"
bundle check || bundle install

# Migrations run only in the dedicated one-shot "migrate" ECS task
# (RUN_DB_MIGRATIONS=true), not in every long-running service replica -
# running db:create/schema:load/migrate concurrently from multiple replicas
# on every deploy/scale-out would race against each other.
if [ "$RUN_DB_MIGRATIONS" = "true" ]; then
  echo "database migration"
  bundle exec rails db:create
  bundle exec rails db:schema:load
  bundle exec rails db:migrate
fi

if [ -f tmp/pids/server.pid ]; then
  rm tmp/pids/server.pid
fi

exec "$@"
