# OpenProject Gitea integration

Connects [Gitea](https://about.gitea.com) and [Forgejo](https://forgejo.org) to OpenProject the way the
built-in GitHub and GitLab integrations do, and covers Gitea Actions as well. Pull requests, issues,
branches and commits that mention a work package show up in a **Gitea** tab on that work package, along
with their CI checks and workflow runs. State changes are posted as comments in the work package's activity.

Requires OpenProject 18. Tested with Gitea 28.3 and act_runner 0.6. Forgejo sends the same webhooks
(with `X-Forgejo-*` headers) and works the same way.

## What gets linked


| In Gitea                                                                                                       | In OpenProject                                                                                               |
| -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| Pull request opened, merged, closed, reopened (title or description mentions `OP#42`)                          | Listed in the tab with its state, branches, diff size, labels and review state; one comment per state change |
| Pull request edited or synchronized                                                                            | Data updated; a "referenced" comment only for newly mentioned work packages                                  |
| Review: approved, changes requested, commented                                                                 | Review state shown on the pull request; comment with the review text                                         |
| Comment on an issue or pull request mentioning `OP#42`                                                         | Item linked; the comment is quoted in the activity                                                           |
| Issue opened, closed, reopened                                                                                 | Listed with state and labels; one comment per state change                                                   |
| Commit pushed with `OP#42` in its message                                                                      | Listed with author and checks; one comment per commit                                                        |
| Branch created whose name starts with the id (`feature/42-checkout`) or contains a semantic id (`fix-proj-42`) | Listed with its latest workflow run and a "Create pull request" button; removed when deleted                 |
| Commit status, from Gitea Actions jobs or any external CI                                                      | Checks on the pull request or commit, failing ones expanded                                                  |
| Workflow run (Gitea Actions)                                                                                   | Latest run status shown on its branch                                                                        |


How references work:

- `OP#42` or `OP#PROJ-42` (semantic ids) links the item and comments on the work package.
- `PP#42` links the item without a comment, a "private" reference.
- Full work package URLs (`https://openproject.example.com/work_packages/42`, `/wp/42`) work like `OP#`.

The tab refreshes itself while it is open, so new pushes, reviews and CI results appear without
reloading the page. The **Git snippets** button offers a branch name, a commit message and a one-line
command that creates a branch with a first commit, all of which link back automatically.

## Try it in two minutes

Needs Docker with Compose 2.24+ and about 8 GB of memory for Docker (the first build compiles
OpenProject's frontend with this plugin).

```shell
bin/dev up
```

This builds OpenProject with the plugin, starts Gitea and an Actions runner, and seeds both sides. The
seed creates a *Webshop* project with three work packages, a *Gitea Bot* user with an API token, the
webhook (with a secret), and a repository `dev/webshop` with a CI workflow. It then plays a short story
in Gitea: an approved, merged pull request with green CI, a draft bugfix with failing CI and requested
changes, an issue with comments, and a deleted branch.


|             | URL                                                                                                          | Login               |
| ----------- | ------------------------------------------------------------------------------------------------------------ | ------------------- |
| OpenProject | [http://localhost:8080/projects/webshop/work_packages](http://localhost:8080/projects/webshop/work_packages) | `admin` / `admin`   |
| Gitea       | [http://localhost:3001/dev/webshop](http://localhost:3001/dev/webshop)                                       | `dev` / `devdevdev` |


Open any of the three work packages and select the **Gitea** tab. Anything you do in Gitea afterwards,
such as pushing a commit with `OP#<id>`, commenting, or re-running a workflow, appears in the tab within
seconds. `bin/dev e2e` checks the whole loop automatically.

Ports can be changed with `OPENPROJECT_PORT` and `GITEA_PORT`.

## Install in production

### Docker

Each release publishes OpenProject with the plugin already installed to the GitHub Container Registry.
It is the official all-in-one image plus this plugin, so it replaces `openproject/openproject` wherever
you use it. Migrations run on start.

| Image | Contents |
| --- | --- |
| `ghcr.io/relism/openproject-gitea:18-rc-1.0.0` | OpenProject `18-rc` + plugin 1.0.0 (pinned) |
| `ghcr.io/relism/openproject-gitea:18-rc` | OpenProject `18-rc` + latest plugin release |

Back up your database before switching images, as for any OpenProject upgrade.

**Single container** (`docker run`): swap the image name in your usual command, keeping your volumes and
environment:

```shell
docker run -d -p 8080:80 --name openproject \
  -e OPENPROJECT_HOST__NAME=openproject.example.com -e OPENPROJECT_SECRET_KEY_BASE=<secret> \
  -v /var/lib/openproject/pgdata:/var/openproject/pgdata \
  -v /var/lib/openproject/assets:/var/openproject/assets \
  ghcr.io/relism/openproject-gitea:18-rc
```

**Docker Compose** ([openproject-docker-compose](https://github.com/opf/openproject-docker-compose)): add a
`docker-compose.override.yml` next to `docker-compose.yml` that points the OpenProject services at this
image, then run `docker compose pull && docker compose up -d`:

```yaml
x-gitea-image: &gitea-image
  image: ghcr.io/relism/openproject-gitea:18-rc

services:
  web: *gitea-image
  worker: *gitea-image
  cron: *gitea-image
  seeder: *gitea-image
```

Then [connect Gitea](#connect-gitea).

**Your own image**: to add the plugin on top of another OpenProject tag, or next to other plugins, build
`docker/Dockerfile` from this repository:

```shell
docker build -f docker/Dockerfile --build-arg OPENPROJECT_IMAGE=openproject/openproject:18-rc -t openproject-gitea .
```

The base must be a full (non-`slim`) image, because the build regenerates the database schema with the
image's own PostgreSQL. `docker/Dockerfile` follows the
[documented plugin recipe](https://www.openproject.org/docs/installation-and-operations/installation/docker/#openproject-plugins)
with two adjustments the recipe misses on OpenProject 18: the base image's precompiled frontend is
rebuilt so it includes the plugin's tab, and the image's PostgreSQL schema cache is removed while assets
are precompiled with the `nulldb` adapter.

### Packaged installation

Add the plugin to `/opt/openproject/Gemfile.plugins` as described in
[Adding plugins](https://www.openproject.org/docs/installation-and-operations/configuration/plugins/), then run
`openproject configure`:

```ruby
group :opf_plugins do
  gem "openproject-gitea_integration", git: "https://github.com/Relism/openproject-gitea_integration", tag: "v1.0.0"
end
```



## Connect Gitea

1. In OpenProject, create a user for Gitea (or pick one), give it a role with *View work packages*,
  *Add comments* and *Show Gitea content* in the relevant projects, and create an API token for it.
2. Enable the **Gitea** module in each project's settings.
3. Under *Administration → Integrations → Gitea*, select that user as the actor and set a webhook
  secret. The page repeats the next step with your instance's URL.
4. In Gitea, on a repository or organization, go to *Settings → Webhooks → Add webhook → Gitea*:
  - Target URL: `https://<openproject>/webhooks/gitea?key=<API token>`
  - HTTP method `POST`, content type `application/json`, the same secret
  - Trigger on *All events*, or at least *Create, Delete, Push, Issues, Issue Comment, Pull Request,
  Pull Request Comment, Pull Request Reviewed, Pull Request Synchronized, Commit Status, Workflow Run*

If Gitea cannot reach OpenProject on a private network, add OpenProject's host to Gitea's
`[security] ALLOWED_HOST_LIST`.

## Development

Everything runs in containers. `bin/dev` is the only entry point:


| Command                                                  | What it does                                                                              |
| -------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| `bin/dev up`                                             | Build and start the demo stack and seed it (idempotent)                                   |
| `bin/dev sync`                                           | Copy the plugin's code into the running OpenProject and restart it (Ruby and ERB changes) |
| `bin/dev up --build`                                     | Rebuild after frontend changes (`frontend/`, `config/locales/js-*.yml`)                   |
| `bin/dev e2e`                                            | Verify the seeded demo end to end, including a live push                                  |
| `bin/dev test [paths]`                                   | Run the specs (default: all) in a container with OpenProject core                         |
| `bin/dev lint`                                           | RuboCop with OpenProject's own configuration                                              |
| `bin/dev record`                                         | Re-record the webhook fixtures from a real Gitea                                          |
| `bin/dev logs`, `console`, `test-shell`, `down`, `reset` | Logs, Rails console, shell in the test container, stop, wipe                              |


`bin/dev test spec/models/gitea_models_spec.rb:12` takes plugin-relative paths. `SKIP_ASSETS=1` skips
the frontend build when you are not running feature specs.

How it fits together:

- **Core checkout.** `bin/dev test` clones the OpenProject version named in `.openproject-version` into
`.openproject/` (git-ignored). The test image is built from core's own CI image, so Ruby, Node and
Chrome versions match core exactly. Plugin specs run inside core, as for any OpenProject plugin.
- **Recorded fixtures.** `spec/fixtures/gitea_webhooks` holds real deliveries from Gitea, captured by  
`bin/dev record`, which plays `dev/scenario.rb` (the same story the demo seed uses) against a live  
Gitea and Actions runner. Work package references are stored as `${wp1}` placeholders that the  
specs fill in. Re-record after upgrading Gitea to catch payload changes.
- **Two-way Docker networking.** Gitea delivers webhooks to `http://openproject/webhooks/gitea`; the
runner registers itself with a shared token and runs jobs in small Alpine containers.



### Layout

```
app/                 models, Primer view components, controllers, cleanup job
lib/open_project/gitea_integration/
  engine.rb          plugin registration, permissions, tab, webhook, API link, cron
  hook_handler.rb    authentication, signature check, dispatch by X-Gitea-Event
  handlers/          one class per Gitea event
  references.rb      OP#/PP#/URL/branch name parsing
frontend/module/     Angular shim that mounts the server-rendered tab
dev/                 Gitea API client, demo story, seed, recorder, end-to-end check
docker/              production/demo image, test image, test runner
spec/                unit, handler, component, request and feature specs
```



## License

GPLv3, like OpenProject. See [LICENSE](LICENSE).