module Git
  module Pr
    module Release
      class PullRequest
        include Git::Pr::Release::Util
        extend Git::Pr::Release::Util
        attr_reader :pr

        def initialize(pr)
          @pr = pr
        end

        def to_checklist_item(print_title = false)
          if print_title
            "- [ ] ##{pr.number} #{pr.title}" + mention
          else
            "- [ ] ##{pr.number}" + mention
          end
        end

        def html_link
          pr.rels[:html].href
        end

        def to_hash
          { :data => @pr.to_hash }
        end

        def mention
          mention = case PullRequest.mention_type
                    when 'author'
                      pr.user ? "@#{pr.user.login}" : nil
                    else
                      pr.assignee ? "@#{pr.assignee.login}" : pr.user ? "@#{pr.user.login}" : nil
                    end

          mention ? " #{mention}" : ""
        end

        def self.mention_type
          @mention_type ||= (ENV.fetch('GIT_PR_RELEASE_MENTION') { git_config('mention') } || 'default')
        end

        def method_missing(name, *args, &block)
          @pr.public_send name, *args, &block
        end

        def respond_to_missing?(name, include_private = false)
          @pr.respond_to?(name, include_private)
        end
      end
    end
  end
end
