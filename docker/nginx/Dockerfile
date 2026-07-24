FROM nginx
WORKDIR /var/app

# nginx's docker-entrypoint envsubst's every /etc/nginx/templates/*.template
# into /etc/nginx/conf.d/*.conf at container start, substituting RAILS_UPSTREAM
# (see default.conf.template). Default matches docker-compose's bridge network
# alias; ECS overrides this to 127.0.0.1 via the task definition.
COPY docker/nginx/default.conf.template /etc/nginx/templates/default.conf.template
ENV RAILS_UPSTREAM=rails_app

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
