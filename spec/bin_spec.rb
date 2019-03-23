load File.expand_path("../bin/git-pr-release", __dir__)

RSpec.describe "git-pr-release" do
  before do
    Timecop.freeze(Time.parse("2019-02-20 22:58:35"))

    @stubs = Faraday::Adapter::Test::Stubs.new
    @agent = Sawyer::Agent.new "http://foo.com/a/" do |conn|
      conn.builder.handlers.delete(Faraday::Adapter::NetHttp)
      conn.adapter :test, @stubs
    end
    @release_pr = Sawyer::Resource.new(@agent, YAML.load_file(file_fixture("pr_1.yml")))
    @merged_prs = [
      Sawyer::Resource.new(@agent, YAML.load_file(file_fixture("pr_3.yml"))),
      Sawyer::Resource.new(@agent, YAML.load_file(file_fixture("pr_6.yml"))),
    ]
    @changed_files = [
      Sawyer::Resource.new(@agent, YAML.load_file(file_fixture("pr_1_files.yml"))),
    ]
  end

  describe "#build_pr_title_and_body" do
    context "without any options" do
      it {
        pr_title, new_body = build_pr_title_and_body(@release_pr, @merged_prs, @changed_files)
        expect(pr_title).to eq "Release 2019-02-20 22:58:35 +0900"
        expect(new_body).to eq <<~MARKDOWN
          - [ ] #3 Provides a creating release pull-request object for template @hakobe
          - [ ] #6 Support two factor auth @ninjinkun
        MARKDOWN
      }
    end

    context "with ENV" do
      before {
        ENV["GIT_PR_RELEASE_TEMPLATE"] = "spec/fixtures/file/template_1.erb"
      }

      after {
        ENV["GIT_PR_RELEASE_TEMPLATE"] = nil
      }

      it {
        pr_title, new_body = build_pr_title_and_body(@release_pr, @merged_prs, @changed_files)
        expect(pr_title).to eq "a"
        expect(new_body).to eq <<~MARKDOWN
          b
        MARKDOWN
      }
    end

    context "with git_config template" do
      before {
        expect(self).to receive(:git_config).with("template") { "spec/fixtures/file/template_2.erb" }
      }

      it {
        pr_title, new_body = build_pr_title_and_body(@release_pr, @merged_prs, @changed_files)
        expect(pr_title).to eq "c"
        expect(new_body).to eq <<~MARKDOWN
          d
        MARKDOWN
      }
    end
  end

  describe "#dump_result_as_json" do
    it {
      output = capture(:stdout) { dump_result_as_json(@release_pr, @merged_prs, @changed_files) }
      parsed_output = JSON.parse(output)

      expect(parsed_output.keys).to eq %w[release_pull_request merged_pull_requests changed_files]
      expect(parsed_output["release_pull_request"]).to eq({ "data" => JSON.parse(@release_pr.to_hash.to_json) })
      expect(parsed_output["merged_pull_requests"]).to eq @merged_prs.map {|e| JSON.parse(PullRequest.new(e).to_hash.to_json) }
      expect(parsed_output["changed_files"]).to eq @changed_files.map {|e| JSON.parse(e.to_hash.to_json) }
    }
  end

  describe "#merge_pr_body" do
    context "new pr added" do
      it {
        actual = merge_pr_body(<<~OLD_BODY, <<~NEW_BODY)
          - [x] #3 Provides a creating release pull-request object for template @hakobe
          - [ ] #6 Support two factor auth @ninjinkun
        OLD_BODY
          - [ ] #3 Provides a creating release pull-request object for template @hakobe
          - [ ] #4 use user who create PR if there is no assignee @hakobe
          - [ ] #6 Support two factor auth @ninjinkun
        NEW_BODY

        expect(actual).to eq <<~MARKDOWN.chomp
          - [x] #3 Provides a creating release pull-request object for template @hakobe
          - [ ] #4 use user who create PR if there is no assignee @hakobe
          - [ ] #6 Support two factor auth @ninjinkun
        MARKDOWN
      }
    end
    context "new pr added and keeping task status" do
      it {
        actual = merge_pr_body(<<~OLD_BODY, <<~NEW_BODY)
          - [x] #4 use user who create PR if there is no assignee @hakobe
          - [x] #6 Support two factor auth @ninjinkun
        OLD_BODY
          - [ ] #3 Provides a creating release pull-request object for template @hakobe
          - [ ] #4 use user who create PR if there is no assignee @hakobe
          - [ ] #6 Support two factor auth @ninjinkun
        NEW_BODY

        expect(actual).to eq <<~MARKDOWN.chomp
          - [ ] #3 Provides a creating release pull-request object for template @hakobe
          - [x] #4 use user who create PR if there is no assignee @hakobe
          - [x] #6 Support two factor auth @ninjinkun
        MARKDOWN
      }
    end
  end

  describe "#host_and_repository_and_scheme" do
    it {
      expect(self).to receive(:git).with(:config, "remote.origin.url") { ["https://github.com/motemen/git-pr-release\n"] }
      expect(host_and_repository_and_scheme).to eq [nil, "motemen/git-pr-release", "https"]
    }
    it {
      expect(self).to receive(:git).with(:config, "remote.origin.url") { ["ssh://git@github.com/motemen/git-pr-release.git\n"] }
      expect(host_and_repository_and_scheme).to eq [nil, "motemen/git-pr-release", "https"]
    }
    it {
      expect(self).to receive(:git).with(:config, "remote.origin.url") { ["http://ghe.example.com/motemen/git-pr-release\n"] }
      expect(host_and_repository_and_scheme).to eq ["ghe.example.com", "motemen/git-pr-release", "http"]
    }
    it {
      expect(self).to receive(:git).with(:config, "remote.origin.url") { ["ssh://git@ghe.example.com/motemen/git-pr-release.git\n"] }
      expect(host_and_repository_and_scheme).to eq ["ghe.example.com", "motemen/git-pr-release", "https"]
    }
  end
end
