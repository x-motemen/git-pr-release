RSpec.describe Git::Pr::Release::CLI do
  describe ".start" do
    subject { Git::Pr::Release::CLI.start }

    before {
      Timecop.freeze(Time.parse("2020-01-04 16:51:09+09:00"))
      @agent = Sawyer::Agent.new("http://example.com/") do |conn|
        conn.builder.handlers.delete(Faraday::Adapter::NetHttp)
        conn.adapter(:test, Faraday::Adapter::Test::Stubs.new)
      end

      ### Set up configuration
      expect(Git::Pr::Release::CLI).to receive(:host_and_repository_and_scheme).with(no_args) {
        ["github.com", "motemen/git-pr-release", "https"]
      }
      expect(Git::Pr::Release::CLI).to receive(:git_config).with("branch.production") { nil }
      expect(Git::Pr::Release::CLI).to receive(:git_config).with("branch.staging") { nil }
      expect(Git::Pr::Release::CLI).to receive(:git).with(:remote, "update", "origin") {
        []
      }

      ### Fetch merged PRs
      expect(Git::Pr::Release::CLI).to receive(:git).with(:log, "--merges", "--pretty=format:%P", "origin/master..origin/staging") {
        <<~GIT_LOG.each_line
          ad694b9c2b868e8801f9209f0ad5dd5458c49854 42bd43b80c973c8f348df3521745201be05bf194
          b620bead10831d2e4e15be392e0a435d3470a0ad 5c977a1827387ac7b7a85c7b827ee119165f1823
        GIT_LOG
      }
      expect(Git::Pr::Release::CLI).to receive(:git).with("ls-remote", "origin", "refs/pull/*/head") {
        <<~GIT_LS_REMOTE.each_line
          bbcd2a04ef394e91be44c24e93e52fdbca944060        refs/pull/1/head
          5c977a1827387ac7b7a85c7b827ee119165f1823        refs/pull/3/head
          42bd43b80c973c8f348df3521745201be05bf194        refs/pull/4/head
        GIT_LS_REMOTE
      }
      expect(Git::Pr::Release::CLI).to receive(:git).with("merge-base", "5c977a1827387ac7b7a85c7b827ee119165f1823", "origin/master") {
        "b620bead10831d2e4e15be392e0a435d3470a0ad".each_line
      }
      expect(Git::Pr::Release::CLI).to receive(:git).with("merge-base", "42bd43b80c973c8f348df3521745201be05bf194", "origin/master") {
        "b620bead10831d2e4e15be392e0a435d3470a0ad".each_line
      }

      ### Create a release PR
      client = double(Octokit::Client)
      expect(client).to receive(:pull_request).with("motemen/git-pr-release", 3) {
        Sawyer::Resource.new(@agent, YAML.load_file(file_fixture("pr_3.yml")))
      }
      expect(client).to receive(:pull_request).with("motemen/git-pr-release", 4) {
        Sawyer::Resource.new(@agent, YAML.load_file(file_fixture("pr_4.yml")))
      }
      expect(client).to receive(:pull_requests).with("motemen/git-pr-release") {
        []
      }
      created_pr = double(
        number: 1023,
        rels: { html: double(href: "https://github.com/motemen/git-pr-release/pull/1023") }
      )
      expect(client).to receive(:create_pull_request).with("motemen/git-pr-release", "master", "staging", "Preparing release pull request...", "") {
        created_pr
      }
      pr_title = "Release 2020-01-04 16:51:09 +0900"
      pr_body = <<~BODY
        - [ ] #3 Provides a creating release pull-request object for template @hakobe
        - [ ] #4 use user who create PR if there is no assignee @motemen
      BODY
      expect(Git::Pr::Release::CLI).to receive(:build_pr_title_and_body) {
        [pr_title, pr_body]
      }
      expect(client).to receive(:update_pull_request).with(
        "motemen/git-pr-release",
        1023,
        {
          body: pr_body,
          title: pr_title,
        }
      ) {
        created_pr
      }
      allow(Git::Pr::Release::CLI).to receive(:client).with(no_args) {
        client
      }
      expect(Git::Pr::Release::CLI).to receive(:pull_request_files).with(client, nil) { nil }
      expect(Git::Pr::Release::CLI).to receive(:pull_request_files).with(client, created_pr) { nil }
      expect(Git::Pr::Release::CLI).to receive(:git_config).with("labels") { nil }
    }

    it { is_expected.to eq nil }
  end
end
