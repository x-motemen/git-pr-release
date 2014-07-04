require 'tmpdir'
require 'pathname'
require 'helper'
require 'octokit'
require 'open3'

ROOT = Pathname.new(__FILE__).parent.parent

def git(*args)
  system('git', *args.map { |a| a.to_s })
end

# def Open3.capture2(*command)
#   p command
# end

RSpec.configure do |c|
  c.before :all do
    test_github_host = test_github_enterprise_host || 'github.com'

    @repo_dir = Pathname.new(Dir.mktmpdir)
    repo_url  = "ssh://git@#{test_github_host}/#{test_github_user}/#{test_github_project}"

    STDERR.puts "# Repo dir: #@repo_dir"
    STDERR.puts "# Repo URL: #{repo_url}"

    git :clone, "ssh://git@#{test_github_host}/#{test_github_user}/#{test_github_project}", @repo_dir.to_s

    if false
      id = Time.now.to_i.to_s

      Dir.chdir @repo_dir do
        git :checkout, 'staging' # FIXME or git checkout -b staging
        git :push, 'origin', 'staging'

        git :checkout, 'master'

        git :checkout, '-b', "feature-#{id}", 'staging'
        File.open("file-#{id}", 'w') { |io| io.puts "file-#{id}" }
        git :add, "file-#{id}"
        git :commit, '-m', "a commit in feature-#{id}"
        git :push, 'origin', "feature-#{id}"
      end

      options = { :access_token => test_github_token }

      if test_github_host != 'github.com'
        OpenSSL::SSL.const_set :VERIFY_PEER, OpenSSL::SSL::VERIFY_NONE # XXX

        Octokit.configure do |c|
          options[:api_endpoint] = "https://#{test_github_host}/api/v3"
          options[:web_endpoint] = "https://#{test_github_host}/"
        end
      end

      @octokit = Octokit::Client.new(options)

      VCR.use_cassette('prepare_merged_pull_request') do
        pr = @octokit.create_pull_request(
          "#{test_github_user}/#{test_github_project}", 'staging', "feature-#{id}", "feature #{id}", ''
        )
        p @octokit.merge_pull_request(
          "#{test_github_user}/#{test_github_project}", pr.number, 'merge pr'
        ) rescue nil
      end
    end

  end

# c.after(:all) do
#   FileUtils.remove_entry @repo_dir
# end
end

describe 'git-pr-release' do
  it 'successfully creates a pull request' do
    VCR.use_cassette('default') do
      Dir.chdir @repo_dir do
        load ROOT + 'bin/git-pr-release', true
      end
    end
  end
end
