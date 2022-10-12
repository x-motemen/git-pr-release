# git-pr-release <a href="http://badge.fury.io/rb/git-pr-release"><img src="https://badge.fury.io/rb/git-pr-release@2x.png" alt="Gem Version" height="18"></a>

Creates a "release pull request", whose body consists of features list or
pull requests that are to be released into production. It's especially useful for QA and
pre-release checks. `git-pr-release` automatically collect pull requests
merged into master branch and generates the content of the release
pull request.

![Screenshot](https://cloud.githubusercontent.com/assets/113420/3147184/61bf2eec-ea53-11e3-835b-50d63ed11b39.png)

Suitable for branching strategy like below (similar to git-flow):

- Feature branches are first merged into "staging" (or release, development)
  branch.
- Then the staging branch is merged into "production" branch, which is for
  production release.

## Usage

`git-pr-release`: default

`git-pr-release --squashed`: include PRs containing squashed commits.

`git-pr-release --overwrite-description`: generate a fresh PR description.

`git-pr-release -n` | `git-pr-release --dry-run`: perform a dry run; does not update PR.

`git-pr-release --no-fetch`: Do not fetch from remote repo before determining target PRs (CI friendly).

`git-pr-release --json`: Show data of target PRs in JSON format.

## Configuration

All configuration are taken using `git config`. You can write these variables
in file `.git-pr-release` (instead of `.git/config` or `~/.gitconfig`) to share project-wise configuration to other
collaborators.

### `pr-release.token`

Token for GitHub API.

If not set, you will be asked to input username/password for one time only,
and this configuration variable will be stored.

You can specify this value by `GIT_PR_RELEASE_TOKEN` environment variable.

### `pr-release.branch.production`

The branch name that is deployed in production environment.

You can specify this value by `GIT_PR_RELEASE_BRANCH_PRODUCTION` environment variable.

Default value: `master`.

### `pr-release.branch.staging`

The branch name that the feature branches are merged into and is going to be
merged into the "production" branch.

You can specify this value by `GIT_PR_RELEASE_BRANCH_STAGING` environment variable.

Default value: `staging`.

### `pr-release.template`

The template file path (relative to the workidir top) for pull requests
created. Its first line is used for the PR title, the rest for the body. This
is an ERB template.

You can specify this value by `GIT_PR_RELEASE_TEMPLATE` environment variable.

If not specified, the content below is used as the template (embedded in the code):

```erb
Release <%= Time.now %>
<% pull_requests.each do |pr| -%>
<%=  pr.to_checklist_item %>
<% end -%>
```

### `pr-release.labels`

The labels list for adding to pull requests created.
This value should be comma-separated strings.

You can specify this value by `GIT_PR_RELEASE_LABELS` environment variable.

If not specified, any labels will not be added for PRs.

### `pr-release.mention`

The name that is listed next to each PR title.
Accepted values: `author`

You can specify this value by `GIT_PR_RELEASE_MENTION` environment variable.

If not specified, the mention will be the PR assignee

### `pr-release.ssl-no-verify`

Whether to verify SSL certificate or not.
Accepted values: `true` | `false`

This option might be useful when self-hosted GitHub enterprise server is using self-signed certificate.

You can specify this value by `GIT_PR_RELEASE_SSL_NO_VERIFY` to `1`.

If not specified, verify SSL certificate always.

## Errors and exit statuses

### No pull requests to be released

exit status is 1.

## Author

motemen <motemen@gmail.com>, original in-house version written by @hitode909.
