# syntax=docker/dockerfile:1.7
# Test image: OpenProject core (pinned checkout in .openproject) + this plugin, built on core's own CI image
# (Ruby, Node, Chrome, Postgres client). Plugin code is synced into the running container by `bin/dev test`,
# so code changes never invalidate the slow bundle/npm layers below.
FROM base

COPY --chown=dev:dev . /app
COPY --from=plugin --chown=dev:dev openproject-gitea_integration.gemspec /app/vendor/plugins/openproject-gitea_integration/

RUN printf 'group :opf_plugins do\n  gem "openproject-gitea_integration", path: "vendor/plugins/openproject-gitea_integration"\nend\n' > Gemfile.plugins \
 && cp docker/ci/database.yml config/database.yml \
 && bundle install --jobs 8 --quiet

RUN JOBS=8 npm install --quiet --no-audit --no-fund

COPY --from=plugin --chown=dev:dev docker/test-runner /usr/local/bin/test-runner

ENTRYPOINT []
CMD ["sleep", "infinity"]
