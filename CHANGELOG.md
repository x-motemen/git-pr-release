# git-pr-release

## v2.2.0.1 (2023-06-20)

[full changelog](https://github.com/shimx/git-pr-release/compare/v2.2.0...v2.2.0.1)

- (https://github.com/shimx/git-pr-release/pull/2) (@shimx)

## v2.2.0 (2022-08-17)

[full changelog](https://github.com/x-motemen/git-pr-release/compare/v2.1.2...v2.2.0)

* (#88) unshallow if a shallow repository (@Songmu)
* (#89) Add overwrite-description option (@onk)

## v2.1.2 (2022-07-29)

[full changelog](https://github.com/x-motemen/git-pr-release/compare/v2.1.1...v2.1.2)

* (#87) delegate to `@pr` when `method_missing` in PullRequest (@Songmu)

## v2.1.1 (2022-03-09)

[full changelog](https://github.com/x-motemen/git-pr-release/compare/v2.1.0...v2.1.1)

* (#81) fix forbidden git config name (#80) (@mtgto)

## v2.1.0 (2022-03-03)

[full changelog](https://github.com/x-motemen/git-pr-release/compare/v2.0.0...v2.1.0)

* (#75) reduce GitHub search API calls when the squashed option is specified (@Songmu)
* (#76) use bulk issue search to reduce API calls (@Songmu)
* (#77) Add option "ssl_no_verify" to skip verifying ssl certificate (@mtgto)
* (#78) add an argument to to_checklist_item to print pr title (@mtgto)

## v2.0.0 (2022-02-17)

[full changelog](https://github.com/x-motemen/git-pr-release/compare/v1.9.0...v2.0.0)

* (#69) remove duplicated PR entries at squash (@Yuki-Inoue)
* (#70) [Spec] Fix spec for build_pr_title_and_body (@yutailang0119)
* (#71) Introduce CI (@ohbarye)
* (#73) (#74) Use `YAML.unsafe_load_file` instead of `YAML.load_file` (@ohbarye)

## v1.9.0 (2021-08-04)

[full changelog](https://github.com/x-motemen/git-pr-release/compare/v1.8.0...v1.9.0)

* (#68) Add nil check for release\_pr.body (@w1mvy)

## v1.8.0 (2021-06-24)

[full changelog](https://github.com/x-motemen/git-pr-release/compare/v1.7.0...v1.8.0)

* (#66) Exclude titles from checklist items (@nhosoya)

## v1.7.0 (2021-05-24)

[full changelog](https://github.com/x-motemen/git-pr-release/compare/v1.6.0...v1.7.0)

* (#64) fix wrong pr number due to sleep (@mpon)

## v1.6.0 (2021-05-15)

[full changelog](https://github.com/x-motemen/git-pr-release/compare/v1.5.0...v1.6.0)

* (#63) Sort merged_pull_request_numbers numerically by default (@yutailang0119)

## v1.5.0 (2021-04-02)

[full changelog](https://github.com/x-motemen/git-pr-release/compare/v1.4.0...v1.5.0)

* (#60, #61) Get issue number from GitHub API for squashed PR (@yuuan)
* (#58) Make stable test (@kachick)
* (#55) Suppress warning for ERB (@ohbarye)
* (#50) support `GIT_PR_RELEASE_MENTION` environment variable (@dabutvin)
* (#49) Transfer repository to x-motemen organization (@onk)

## v1.4.0 (2020-02-22)

[full changelog](https://github.com/x-motemen/git-pr-release/compare/v1.3.0...v1.4.0)

* (#48) List PR API needs head user or head organization and branch name (@sasasin)

## v1.3.0 (2020-02-19)

[full changelog](https://github.com/x-motemen/git-pr-release/compare/v1.2.0...v1.3.0)

* (#47) Fix Errno::ENOENT when finding the specified template (@onk)
* (#45) Fix "warning: instance variable @xxx not initialized" (@onk)

## v1.2.0 (2020-02-07)

[full changelog](https://github.com/x-motemen/git-pr-release/compare/v1.1.0...v1.2.0)

* (#44) Use API option when detecting existing release PR (@onk)
* (#41, #42) Refactor (@onk)
  - Some local variables are removed. This will break if you have customized the template ERB.

## v1.1.0 (2020-01-02)

[full changelog](https://github.com/x-motemen/git-pr-release/compare/v1.0.1...v1.1.0)

* (#38) Fetch changed files as many as possible (@shibayu36)

## v1.0.1 (2019-12-17)

[full changelog](https://github.com/x-motemen/git-pr-release/compare/v1.0.0...v1.0.1)

* (#37) Fix NameError (@onk)

## v1.0.0 (2019-12-14)

* (#35) Do not define classes and methods at the top level (@onk)
* (#30) Extract logic from bin/git-pr-release (@banyan)

...

## v0.0.1 (2014-01-21)

Initial Release
