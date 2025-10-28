RSpec.describe Git::Pr::Release::PullRequest do
  before do
    @stubs = Faraday::Adapter::Test::Stubs.new
    @agent = Sawyer::Agent.new "http://foo.com/a/" do |conn|
      conn.builder.handlers.delete(Faraday::Adapter::NetHttp)
      conn.adapter :test, @stubs
    end
  end

  describe "#mention" do
    context "with multiple assignees" do
      it "returns all assignees as mentions" do
        pr_data = Sawyer::Resource.new(@agent, load_yaml("pr_7.yml"))
        pull_request = Git::Pr::Release::PullRequest.new(pr_data)
        expect(pull_request.mention).to eq " @hakobe @ninjinkun @motemen"
      end
    end

    context "with single assignee (backward compatibility)" do
      it "returns single assignee mention when assignees is empty but assignee is set" do
        pr_data = Sawyer::Resource.new(@agent, load_yaml("pr_3.yml"))
        # Modify the data to have a single assignee
        pr_data.assignee = Sawyer::Resource.new(@agent, {
          login: "hakobe",
          id: 6882
        })
        pr_data.assignees = []
        pull_request = Git::Pr::Release::PullRequest.new(pr_data)
        expect(pull_request.mention).to eq " @hakobe"
      end
    end

    context "with no assignees" do
      it "returns PR creator as mention" do
        pr_data = Sawyer::Resource.new(@agent, load_yaml("pr_3.yml"))
        pull_request = Git::Pr::Release::PullRequest.new(pr_data)
        expect(pull_request.mention).to eq " @hakobe"
      end
    end

    context "when mention_type is 'author'" do
      before do
        allow(Git::Pr::Release::PullRequest).to receive(:mention_type).and_return('author')
      end

      it "returns PR author regardless of assignees" do
        pr_data = Sawyer::Resource.new(@agent, load_yaml("pr_7.yml"))
        pull_request = Git::Pr::Release::PullRequest.new(pr_data)
        expect(pull_request.mention).to eq " @hakobe"
      end
    end
  end

  describe "#to_checklist_item" do
    context "with multiple assignees" do
      it "includes all assignees in the checklist item" do
        pr_data = Sawyer::Resource.new(@agent, load_yaml("pr_7.yml"))
        pull_request = Git::Pr::Release::PullRequest.new(pr_data)
        expect(pull_request.to_checklist_item).to eq "- [ ] #7 @hakobe @ninjinkun @motemen"
      end

      it "includes title when print_title is true" do
        pr_data = Sawyer::Resource.new(@agent, load_yaml("pr_7.yml"))
        pull_request = Git::Pr::Release::PullRequest.new(pr_data)
        expect(pull_request.to_checklist_item(true)).to eq "- [ ] #7 Support multiple assignees @hakobe @ninjinkun @motemen"
      end
    end
  end
end
