git-pr-release
==============

Configuration
-------------

All configuration are taken using `git config`.

### `pr-release.token`

Token for GitHub API.

If not set, you will be asked to input username/password for one time only,
and this configuration variable will be stored.

### `pr-release.branch.production`

The branch name that is deployed in production environment.

Default value: `master`.

### `pr-release.branch.staging`

The branch name that the feature branches are merged into and is going to be
merged into the "production branch".

Default value: `staging`.
