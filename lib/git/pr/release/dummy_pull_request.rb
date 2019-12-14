module Git
  module Pr
    module Release
      class DummyPullRequest
        def initialize
          # nop
        end

        def to_checklist_item
          "- [ ] #??? THIS IS DUMMY PULL REQUEST"
        end

        def html_link
          'http://github.com/DUMMY/DUMMY/issues/?'
        end

        def to_hash
          { :data => {} }
        end
      end
    end
  end
end
