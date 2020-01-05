RSpec.describe Git::Pr::Release::CLI do
  describe "#start" do
    subject { @cli.start }

    before {
      @cli = Git::Pr::Release::CLI.new

      Timecop.freeze(Time.parse("2020-01-04 16:51:09+09:00"))
      @agent = Sawyer::Agent.new("http://example.com/") do |conn|
        conn.builder.handlers.delete(Faraday::Adapter::NetHttp)
        conn.adapter(:test, Faraday::Adapter::Test::Stubs.new)
      end

      ### Set up configuration
      expect(@cli).to receive(:configure)
      allow(@cli).to receive(:repository) { "motemen/git-pr-release" }
      allow(@cli).to receive(:production_branch) { "master" }
      allow(@cli).to receive(:staging_branch) { "staging" }

      ### Fetch merged PRs
      expect(@cli).to receive(:fetch_merged_prs) {
        [
          Sawyer::Resource.new(@agent, YAML.load_file(file_fixture("pr_3.yml"))),
          Sawyer::Resource.new(@agent, YAML.load_file(file_fixture("pr_4.yml"))),
        ]
      }

      ### Create a release PR
      client = double(Octokit::Client)
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
      expect(@cli).to receive(:build_pr_title_and_body) {
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
      allow(@cli).to receive(:client).with(no_args) {
        client
      }
      expect(@cli).to receive(:pull_request_files).with(client, nil) { nil }
      expect(@cli).to receive(:pull_request_files).with(client, created_pr) { nil }
      expect(@cli).to receive(:git_config).with("labels") { nil }
    }

    it { is_expected.to eq 0 }
  end

  describe "#configure" do
    subject { @cli.configure }

    before { @cli = Git::Pr::Release::CLI.new }

    context "When default" do
      before {
        allow(@cli).to receive(:host_and_repository_and_scheme) {
          [nil, "motemen/git-pr-release", "https"]
        }
        allow(@cli).to receive(:git_config).with("branch.production") { nil }
        allow(@cli).to receive(:git_config).with("branch.staging") { nil }
      }

      it "configured as default" do
        subject

        expect(Octokit.api_endpoint).to eq "https://api.github.com/"
        expect(Octokit.web_endpoint).to eq "https://github.com/"

        expect(@cli.instance_variable_get(:@repository)).to eq "motemen/git-pr-release"
        expect(@cli.instance_variable_get(:@production_branch)).to eq "master"
        expect(@cli.instance_variable_get(:@staging_branch)).to eq "staging"
      end
    end

    context "When GitHub Enterprise Server" do
      before {
        allow(@cli).to receive(:host_and_repository_and_scheme) {
          ["example.com", "motemen/git-pr-release", "https"]
        }
      }
      after {
        Octokit.reset!
      }

      it "octokit is configured" do
        subject

        expect(Octokit.api_endpoint).to eq "https://example.com/api/v3/"
        expect(Octokit.web_endpoint).to eq "https://example.com/"
      end
    end

    context "When branches are set by ENV" do
      around do |example|
        original = ENV.to_hash
        begin
          ENV["GIT_PR_RELEASE_BRANCH_PRODUCTION"] = "prod"
          ENV["GIT_PR_RELEASE_BRANCH_STAGING"]    = "dev"
          example.run
        ensure
          ENV.replace(original)
        end
      end

      it "branches are configured" do
        subject

        expect(@cli.instance_variable_get(:@production_branch)).to eq "prod"
        expect(@cli.instance_variable_get(:@staging_branch)).to eq "dev"
      end
    end

    context "When branches are set by git_config" do
      before {
        allow(@cli).to receive(:git_config).with("branch.production") { "production" }
        allow(@cli).to receive(:git_config).with("branch.staging") { "develop" }
      }

      it "branches are configured" do
        subject

        expect(@cli.instance_variable_get(:@production_branch)).to eq "production"
        expect(@cli.instance_variable_get(:@staging_branch)).to eq "develop"
      end
    end
  end
end
