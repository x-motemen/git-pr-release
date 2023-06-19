RSpec.describe Git::Pr::Release::CLI do
  let(:configured_cli) {
    cli = Git::Pr::Release::CLI.new
    allow(cli).to receive(:host_and_repository_and_scheme) {
      [nil, "motemen/git-pr-release", "https"]
    }
    allow(cli).to receive(:git_config).with(anything) { nil }
    cli.configure
    cli
  }

  describe "#start" do
    subject { @cli.start }

    before {
      @cli = Git::Pr::Release::CLI.new

      allow(@cli).to receive(:configure)
      allow(@cli).to receive(:fetch_merged_prs) { merged_prs }
      allow(@cli).to receive(:create_release_pr)
    }

    context "When merged_prs is empty" do
      let(:merged_prs) { [] }
      it {
        is_expected.to eq 1
        expect(@cli).to have_received(:configure)
        expect(@cli).to have_received(:fetch_merged_prs)
        expect(@cli).not_to have_received(:create_release_pr)
      }
    end

    context "When merged_prs exists" do
      let(:merged_prs) {
        agent = Sawyer::Agent.new("http://example.com/") do |conn|
          conn.builder.handlers.delete(Faraday::Adapter::NetHttp)
          conn.adapter(:test, Faraday::Adapter::Test::Stubs.new)
        end
        pr_3 = Sawyer::Resource.new(agent, load_yaml("pr_3.yml"))
        pr_4 = Sawyer::Resource.new(agent, load_yaml("pr_4.yml"))
        [pr_3, pr_4]
      }
      it {
        is_expected.to eq 0
        expect(@cli).to have_received(:configure)
        expect(@cli).to have_received(:fetch_merged_prs)
        expect(@cli).to have_received(:create_release_pr).with(merged_prs)
      }
    end
  end

  describe "#configure" do
    subject { @cli.configure }

    before {
      @cli = Git::Pr::Release::CLI.new

      allow(@cli).to receive(:git_config).with(anything) { nil }
    }

    context "When default" do
      before {
        allow(@cli).to receive(:host_and_repository_and_scheme) {
          [nil, "motemen/git-pr-release", "https"]
        }
      }

      it "configured as default" do
        subject

        expect(Octokit.api_endpoint).to eq "https://api.github.com/"
        expect(Octokit.web_endpoint).to eq "https://github.com/"

        expect(@cli.repository).to eq "motemen/git-pr-release"
        expect(@cli.production_branch).to eq "master"
        expect(@cli.staging_branch).to eq "staging"
        expect(@cli.template_path).to eq nil
        expect(@cli.labels).to eq []
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

    describe "branches" do
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

          expect(@cli.production_branch).to eq "prod"
          expect(@cli.staging_branch).to eq "dev"
        end
      end

      context "When branches are set by git_config" do
        before {
          allow(@cli).to receive(:git_config).with("branch.production") { "production" }
          allow(@cli).to receive(:git_config).with("branch.staging") { "develop" }
        }

        it "branches are configured" do
          subject

          expect(@cli.production_branch).to eq "production"
          expect(@cli.staging_branch).to eq "develop"
        end
      end
    end

    describe "labels" do
      context "With ENV" do
        around do |example|
          original = ENV.to_hash
          begin
            ENV["GIT_PR_RELEASE_LABELS"] = env_labels
            example.run
          ensure
            ENV.replace(original)
          end
        end

        context "string" do
          let(:env_labels) { "release" }
          it "set labels" do
            subject
            expect(@cli.labels).to eq ["release"]
          end
        end

        context "comma separated string" do
          let(:env_labels) { "release,release2" }
          it "set labels" do
            subject
            expect(@cli.labels).to eq ["release", "release2"]
          end
        end

        context "empty string" do
          let(:env_labels) { "" }
          it "set labels as default" do
            subject
            expect(@cli.labels).to eq []
          end
        end
      end

      context "With git_config" do
        before {
          allow(@cli).to receive(:git_config).with("labels") { "release" }
        }

        it "set labels" do
          subject
          expect(@cli.labels).to eq ["release"]
        end
      end
    end
  end

  describe "#fetch_merged_prs" do
    subject { @cli.fetch_merged_prs }

    before {
      @cli = configured_cli

      agent = Sawyer::Agent.new("http://example.com/") do |conn|
        conn.builder.handlers.delete(Faraday::Adapter::NetHttp)
        conn.adapter(:test, Faraday::Adapter::Test::Stubs.new)
      end

      expect(@cli).to receive(:git).with(:'rev-parse', "--is-shallow-repository") { ["false\n"] }
      expect(@cli).to receive(:git).with(:remote, "update", "origin") {
        []
      }

      expect(@cli).to receive(:git).with(:log, "--merges", "--pretty=format:%P", "origin/master..origin/staging") {
        <<~GIT_LOG.each_line
          ad694b9c2b868e8801f9209f0ad5dd5458c49854 42bd43b80c973c8f348df3521745201be05bf194
          b620bead10831d2e4e15be392e0a435d3470a0ad 5c977a1827387ac7b7a85c7b827ee119165f1823
        GIT_LOG
      }
      expect(@cli).to receive(:git).with("ls-remote", "origin", "refs/pull/*/head") {
        <<~GIT_LS_REMOTE.each_line
          bbcd2a04ef394e91be44c24e93e52fdbca944060        refs/pull/1/head
          5c977a1827387ac7b7a85c7b827ee119165f1823        refs/pull/3/head
          42bd43b80c973c8f348df3521745201be05bf194        refs/pull/4/head
        GIT_LS_REMOTE
      }
      expect(@cli).to receive(:git).with("merge-base", "5c977a1827387ac7b7a85c7b827ee119165f1823", "origin/master") {
        "b620bead10831d2e4e15be392e0a435d3470a0ad".each_line
      }
      expect(@cli).to receive(:git).with("merge-base", "42bd43b80c973c8f348df3521745201be05bf194", "origin/master") {
        "b620bead10831d2e4e15be392e0a435d3470a0ad".each_line
      }

      client = double(Octokit::Client)
      @pr_3 = Sawyer::Resource.new(agent, load_yaml("pr_3.yml"))
      @pr_4 = Sawyer::Resource.new(agent, load_yaml("pr_4.yml"))
      expect(client).to receive(:pull_request).with("motemen/git-pr-release", 3) { @pr_3 }
      expect(client).to receive(:pull_request).with("motemen/git-pr-release", 4) { @pr_4 }
      allow(@cli).to receive(:client).with(no_args) { client }
    }

    it { is_expected.to eq [@pr_3, @pr_4] }

    context 'when squashed' do
      before {
        @cli.instance_variable_set(:@squashed, true)
        expect(@cli).to receive(:git).with(
          :log,
          "--pretty=format:%h",
          "--abbrev=7",
          "--no-merges",
          "--first-parent",
          "origin/master..origin/staging"
        ) { ''.each_line }
      }

      it { is_expected.to eq [@pr_3, @pr_4] }
    end

    context 'when squashed and recursive' do
      before {
        @cli.instance_variable_set(:@squashed, true)
        @cli.instance_variable_set(:@recursive, true)
        expect(@cli).to receive(:git).with(
          :log,
          "--pretty=format:%h",
          "--abbrev=7",
          "--no-merges",
          "origin/master..origin/staging"
        ) { ''.each_line }
      }

      it { is_expected.to eq [@pr_3, @pr_4] }
    end
  end

  describe "#create_release_pr" do
    subject { @cli.create_release_pr(@merged_prs) }

    before {
      @cli = configured_cli

      @agent = Sawyer::Agent.new("http://example.com/") do |conn|
        conn.builder.handlers.delete(Faraday::Adapter::NetHttp)
        conn.adapter(:test, Faraday::Adapter::Test::Stubs.new)
      end

      @merged_prs = [
        Sawyer::Resource.new(@agent, load_yaml("pr_3.yml")),
        Sawyer::Resource.new(@agent, load_yaml("pr_4.yml")),
      ]

      allow(@cli).to receive(:detect_existing_release_pr) { existing_release_pr }
      @pr_title = "Release 2020-01-04 16:51:09 +0900"
      @pr_body = <<~BODY.chomp
        - [ ] #3 Provides a creating release pull-request object for template @hakobe
        - [ ] #4 use user who create PR if there is no assignee @motemen
      BODY
      allow(@cli).to receive(:build_and_merge_pr_title_and_body) {
        [@pr_title, @pr_body]
      }
      allow(@cli).to receive(:update_release_pr)
      @changed_files = [double(Sawyer::Resource)]
      allow(@cli).to receive(:pull_request_files) { @changed_files }
    }

    context "When create_mode" do
      before {
        @created_pr = Sawyer::Resource.new(@agent, load_yaml("pr_1.yml"))
        allow(@cli).to receive(:prepare_release_pr) { @created_pr }
      }

      let(:existing_release_pr) { nil }

      it {
        subject

        expect(@cli).to have_received(:detect_existing_release_pr)
        expect(@cli).to have_received(:prepare_release_pr)
        expect(@cli).to have_received(:pull_request_files)
        expect(@cli).to have_received(:build_and_merge_pr_title_and_body).with(@created_pr, @merged_prs, @changed_files)
        expect(@cli).to have_received(:update_release_pr).with(@created_pr, @pr_title, @pr_body)
      }
    end

    context "When not create_mode" do
      before {
        allow(@cli).to receive(:prepare_release_pr)
      }

      let(:existing_release_pr) { double(
        number: 1023,
        rels: { html: double(href: "https://github.com/motemen/git-pr-release/pull/1023") },
      )}

      it {
        subject

        expect(@cli).to have_received(:detect_existing_release_pr)
        expect(@cli).to have_received(:pull_request_files).with(existing_release_pr)
        expect(@cli).not_to have_received(:prepare_release_pr)
        expect(@cli).to have_received(:build_and_merge_pr_title_and_body).with(existing_release_pr, @merged_prs, @changed_files)
        expect(@cli).to have_received(:update_release_pr).with(existing_release_pr, @pr_title, @pr_body)
      }
    end

    context "When dry_run with create_mode" do
      before {
        @created_pr = Sawyer::Resource.new(@agent, load_yaml("pr_1.yml"))
        allow(@cli).to receive(:prepare_release_pr) { @created_pr }

        @cli.instance_variable_set(:@dry_run, true)
      }

      let(:existing_release_pr) { nil }

      it {
        subject

        expect(@cli).to have_received(:detect_existing_release_pr)
        expect(@cli).not_to have_received(:prepare_release_pr)
        expect(@cli).not_to have_received(:pull_request_files)
        expect(@cli).to have_received(:build_and_merge_pr_title_and_body).with(nil, @merged_prs, [])
        expect(@cli).not_to have_received(:update_release_pr).with(@created_pr, @pr_title, @pr_body)
      }
    end

    context "When overwrite_description" do
      before {
        @cli.instance_variable_set(:@overwrite_description, true)
        @new_pr_title = "2022-08-17 12:34:58 +0900"
        @new_pr_body = <<~BODY.chomp
          - [ ] #3 @hakobe
          - [ ] #4 @hakobe
        BODY
        allow(@cli).to receive(:build_pr_title_and_body) {
          [@new_pr_title, @new_pr_body]
        }
      }

      let(:existing_release_pr) { double(
        number: 1023,
        rels: { html: double(href: "https://github.com/motemen/git-pr-release/pull/1023") },
      )}

      it {
        subject

        expect(@cli).not_to have_received(:build_and_merge_pr_title_and_body)
        expect(@cli).to have_received(:update_release_pr).with(existing_release_pr, @new_pr_title, @new_pr_body)
      }
    end
  end

  describe "#prepare_release_pr" do
    subject { @cli.prepare_release_pr }

    before {
      @cli = configured_cli

      @client = double(Octokit::Client)
      allow(@client).to receive(:create_pull_request)
      allow(@cli).to receive(:client) { @client }
    }

    it {
      subject

      expect(@client).to have_received(:create_pull_request).with(
        "motemen/git-pr-release",
        "master",
        "staging",
        "Preparing release pull request...",
        "", # empby body
      )
    }
  end

  describe "#build_and_merge_pr_title_and_body" do
    subject { @cli.build_and_merge_pr_title_and_body(release_pr, @merged_prs, changed_files) }

    before {
      @cli = configured_cli

      @merged_prs = [double(Sawyer::Resource)]
      allow(@cli).to receive(:build_pr_title_and_body) { ["PR Title", "PR Body"] }
      allow(@cli).to receive(:merge_pr_body) { "Merged Body" }
    }

    context "When release_pr exists" do
      let(:release_pr) { double(body: "Old Body") }
      let(:changed_files) { [double(Sawyer::Resource)] }

      it {
        is_expected.to eq ["PR Title", "Merged Body"]

        expect(@cli).to have_received(:build_pr_title_and_body).with(release_pr, @merged_prs, changed_files, nil)
        expect(@cli).to have_received(:merge_pr_body).with("Old Body", "PR Body")
      }
    end

    context "When release_pr is nil" do
      # = When dry_run with create_mode
      let(:release_pr) { nil }
      let(:changed_files) { [] }

      it {
        is_expected.to eq ["PR Title", "Merged Body"]

        expect(@cli).to have_received(:build_pr_title_and_body).with(release_pr, @merged_prs, changed_files, nil)
        expect(@cli).to have_received(:merge_pr_body).with("", "PR Body")
      }
    end
  end

  describe "#update_release_pr" do
    subject { @cli.update_release_pr(@release_pr, "PR Title", "PR Body") }

    before {
      @cli = configured_cli

      @release_pr = double(number: 1023)

      @client = double(Octokit::Client)
      allow(@client).to receive(:update_pull_request) { @release_pr }
      allow(@client).to receive(:add_labels_to_an_issue)
      allow(@cli).to receive(:client) { @client }
    }

    context "Without labels" do
      it {
        subject

        expect(@client).to have_received(:update_pull_request).with(
          "motemen/git-pr-release",
          1023,
          {
            title: "PR Title",
            body: "PR Body",
          }
        )
        expect(@client).not_to have_received(:add_labels_to_an_issue)
      }
    end

    context "With labels" do
      before {
        allow(@cli).to receive(:labels) { ["release"] }
      }
      it {
        subject

        expect(@client).to have_received(:update_pull_request).with(
          "motemen/git-pr-release",
          1023,
          {
            title: "PR Title",
            body: "PR Body",
          }
        )
        expect(@client).to have_received(:add_labels_to_an_issue).with(
          "motemen/git-pr-release", 1023, ["release"]
        )
      }
    end
  end

  describe "#detect_existing_release_pr" do
    subject { @cli.detect_existing_release_pr }

    before {
      @cli = configured_cli

      @client = double(Octokit::Client)
      allow(@cli).to receive(:client).with(no_args) { @client }
    }

    context "When exists" do
      before {
        @release_pr = double(head: double(ref: "staging"), base: double(ref: "master"))
        allow(@client).to receive(:pull_requests) { [@release_pr] }
      }

      it { is_expected.to eq @release_pr }
    end

    context "When not exists" do
      before {
        allow(@client).to receive(:pull_requests) { [] }
      }

      it { is_expected.to be_nil }
    end
  end

  describe "#pull_request_files" do
    subject { @cli.pull_request_files(@release_pr) }

    before {
      @cli = configured_cli

      @release_pr = double(number: 1023)
      @client = double(Octokit::Client)
      @changed_files = [double(Sawyer::Resource)]
      allow(@client).to receive(:pull_request_files) { @changed_files }
      allow(@client).to receive(:auto_paginate=)
      allow(@cli).to receive(:client) { @client }
    }

    it {
      is_expected.to eq @changed_files

      expect(@client).to have_received(:auto_paginate=).with(true)
      expect(@client).to have_received(:pull_request_files).with("motemen/git-pr-release", 1023)
      expect(@client).to have_received(:auto_paginate=).with(false)
    }
  end
end
