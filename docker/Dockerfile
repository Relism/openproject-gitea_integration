# syntax=docker/dockerfile:1.7
# OpenProject with this plugin installed — the image users deploy, and the demo stack's `openproject` service.
# Follows https://www.openproject.org/docs/installation-and-operations/installation/docker/#openproject-plugins
ARG OPENPROJECT_IMAGE=openproject/openproject:18
FROM ${OPENPROJECT_IMAGE}

ENV PLUGIN_PATH=/app/vendor/plugins/openproject-gitea_integration

COPY openproject-gitea_integration.gemspec $PLUGIN_PATH/
RUN printf 'group :opf_plugins do\n  gem "openproject-gitea_integration", path: "%s"\nend\n' "$PLUGIN_PATH" > Gemfile.plugins \
 && bundle config unset deployment && bundle install --quiet && bundle config set deployment true

COPY . $PLUGIN_PATH/

# The base image ships precompiled assets; the plugin's tab and styles need a fresh build.
# Its PostgreSQL schema cache cannot be read by the nulldb adapter used for that build.
RUN --mount=type=cache,target=/root/.npm \
    --mount=type=cache,target=/app/frontend/.angular/cache \
    JOBS=8 npm install --quiet --no-audit --no-fund \
 && rm db/schema_cache.yml \
 && SECRET_KEY_BASE=build-only RAILS_ENV=production DATABASE_URL=nulldb://db \
    bin/rails openproject:plugins:register_frontend assets:precompile \
 && rm -rf node_modules frontend/node_modules tmp/cache/assets log/production.log

# Fresh databases are created from db/structure.sql, so it must contain the plugin's tables;
# this also writes a matching schema cache.
RUN ./docker/prod/setup/dump-schema.sh
