# frozen_string_literal: true

RSpec.describe Git::Pr::Release::PullRequest do
  let(:pr_data) {
    agent = Sawyer::Agent.new "http://foo.com/a/" do |conn|
      conn.builder.handlers.delete(Faraday::Adapter::NetHttp)
      conn.adapter :test, Faraday::Adapter::Test::Stubs.new
    end
    Sawyer::Resource.new(agent, load_yaml(pr_data_yaml))
  }
  subject { described_class.new(pr_data) }

  describe "#mention" do
    context "with multiple assignees" do
      let(:pr_data_yaml) { "pr_7.yml" }

      it "returns all assignees as mentions" do
        expect(subject.mention).to eq " @hakobe @toshimaru @Copilot"
      end
    end

    context "with no assignees" do
      let(:pr_data_yaml) { "pr_3.yml" }

      it "returns PR creator as mention" do
        expect(subject.mention).to eq " @hakobe"
      end
    end

    context "when mention_type is 'author'" do
      let(:pr_data_yaml) { "pr_7.yml" }

      before do
        allow(Git::Pr::Release::PullRequest).to receive(:mention_type).and_return('author')
      end

      it "returns PR author regardless of assignees" do
        expect(subject.mention).to eq " @hakobe"
      end
    end
  end

  describe "#to_checklist_item" do
    context "with multiple assignees" do
      let(:pr_data_yaml) { "pr_7.yml" }

      it "includes all assignees in the checklist item" do
        expect(subject.to_checklist_item).to eq "- [ ] #7 @hakobe @toshimaru @Copilot"
      end

      it "includes title when print_title is true" do
        expect(subject.to_checklist_item(true)).to eq "- [ ] #7 Support multiple assignees @hakobe @toshimaru @Copilot"
      end
    end
  end
end
