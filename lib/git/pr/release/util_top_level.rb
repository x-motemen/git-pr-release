require 'erb'
require 'uri'
require 'open3'
require 'optparse'
require 'json'

require 'colorize'
require 'diff/lcs'

class PullRequest
  include Git::Pr::Release::Util
  extend Git::Pr::Release::Util
  attr_reader :pr

  def initialize(pr)
    @pr = pr
  end

  def to_checklist_item
    "- [ ] ##{pr.number} #{pr.title}" + mention
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
    @mention_type ||= (git_config('mention') || 'default')
  end
end

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
