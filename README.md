git-summarize-release-pull-request
==================================

Configuration
-------------

All configuration are accessed via `git config`.

### `summarize-release-pull-request.token`

Token for GitHub API.

If not set, you will be asked to input username/password for one time only,
and this configuration variable will be stored.

### `summarize-release-pull-request.branch.production`

The branch name that is deployed in production environment.

Default value: `master`.

### `summarize-release-pull-request.branch.staging`

The branch name that the feature branches are merged into and is going to be merged into the "production branch".

Default value: `staging`.
