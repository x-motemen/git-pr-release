git-pr-release
==============

Creates a pull request which summarizes feature branches that are to be
released into production. Useful if your branching storategy is like below:

 * Feature branches are first merged into "staging" (or release, development)
   branch.
 * Then the staging branch is merged into "production" branch, which is for
   production release.

Configuration
-------------

All configuration are taken using `git config`.

### `pr-release.token`

Token for GitHub API.

If not set, you will be asked to input username/password for one time only,
and this configuration variable will be stored.

You can specify this value by `GIT_PR_RELEASE_TOKEN` environment variable.

### `pr-release.branch.production`

The branch name that is deployed in production environment.

Default value: `master`.

### `pr-release.branch.staging`

The branch name that the feature branches are merged into and is going to be
merged into the "production" branch.

Default value: `staging`.

### `pr-release.template`

The template file path (relative to the workidir top) for pull requests created. Its first line is used for the PR title, the rest for the body. This is an ERB template.

If not specified, the content below is used as the template (embedded in the code):

```erb
Release <%= Time.now %>
<% pull_requests.each do |pr| -%>
<%=  pr.to_checklist_item %>
<% end -%>
```
