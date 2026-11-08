# Changelog

## 1.0.0 (2026-11-08)

First release, for OpenProject 18 (built and tested on 18.0 RC).

- Gitea and Forgejo webhooks at `/webhooks/gitea`, authenticated by API key and HMAC signature.
- Pull requests, issues, branches and commits are linked to work packages they reference (`OP#42`,
  `PP#42`, work package URLs, branch names), with journal notes for state changes, reviews and comments.
- Commit statuses (including every Gitea Actions job) and workflow runs are shown on pull requests,
  commits and branches.
- Server-rendered "Gitea" work package tab that refreshes itself while open, plus git snippets.
- Admin settings with setup instructions; nightly cleanup of unlinked records.
