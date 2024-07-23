require 'octokit'
require 'optparse'
require 'cgi'

module Git
  module Pr
    module Release
      class CLI
        include Git::Pr::Release::Util
        attr_reader :repository, :production_branch, :staging_branch, :template_path, :labels

        def self.start
          result = self.new.start
          exit result
        end

        def initialize
          @dry_run  = false
          @json     = false
          @no_fetch = false
          @squashed = false
        end

        def start
          OptionParser.new do |opts|
            opts.on('-n', '--dry-run', 'Do not create/update a PR. Just prints out') do |v|
              @dry_run = v
            end
            opts.on('--json', 'Show data of target PRs in JSON format') do |v|
              @json = v
            end
            opts.on('--no-fetch', 'Do not fetch from remote repo before determining target PRs (CI friendly)') do |v|
              @no_fetch = v
            end
            opts.on('--squashed', 'Handle squash merged PRs') do |v|
              @squashed = v
            end
            opts.on('--overwrite-description', 'Force overwrite PR description') do |v|
              @overwrite_description = v
            end
          end.parse!

          ### Set up configuration
          configure

          ### Fetch merged PRs
          merged_prs = fetch_merged_prs
          if merged_prs.empty?
            say 'No pull requests to be released', :error
            return 1
          end

          ### Create a release PR
          create_release_pr(merged_prs)
          return 0
        end

        def client
          @client ||= Octokit::Client.new :access_token => obtain_token!
        end

        def configure
          host, @repository, scheme = host_and_repository_and_scheme

          if host
            if scheme == 'https' # GitHub Enterprise
              ssl_no_verify = %w[true 1].include? ENV.fetch('GIT_PR_RELEASE_SSL_NO_VERIFY') { git_config('ssl-no-verify') }
              if ssl_no_verify
                OpenSSL::SSL.const_set :VERIFY_PEER, OpenSSL::SSL::VERIFY_NONE
              end
            end

            Octokit.configure do |c|
              c.api_endpoint = "#{scheme}://#{host}/api/v3"
              c.web_endpoint = "#{scheme}://#{host}/"
            end
          end

          @production_branch = ENV.fetch('GIT_PR_RELEASE_BRANCH_PRODUCTION') { git_config('branch.production') } || 'master'
          @staging_branch    = ENV.fetch('GIT_PR_RELEASE_BRANCH_STAGING') { git_config('branch.staging') }       || 'staging'
          @template_path     = ENV.fetch('GIT_PR_RELEASE_TEMPLATE') { git_config('template') }

          _labels = ENV.fetch('GIT_PR_RELEASE_LABELS') { git_config('labels') }
          @labels = _labels && _labels.split(/\s*,\s*/) || []

          say "Repository:        #{repository}", :debug
          say "Production branch: #{production_branch}", :debug
          say "Staging branch:    #{staging_branch}", :debug
          say "Template path:     #{template_path}", :debug
          say "Labels             #{labels}", :debug
        end

        def fetch_merged_prs
          bool = git(:'rev-parse', '--is-shallow-repository').first.chomp
          if bool == 'true'
            git(:fetch, '--unshallow')
          end
          git :remote, 'update', 'origin' unless @no_fetch

          merged_pull_request_numbers = fetch_merged_pr_numbers_from_git_remote
          if @squashed
            merged_pull_request_numbers.concat(fetch_squash_merged_pr_numbers_from_github)
          end

          merged_prs = merged_pull_request_numbers.uniq.sort.map do |nr|
            pr = client.pull_request repository, nr
            say "To be released: ##{pr.number} #{pr.title}", :notice
            pr
          end

          merged_prs
        end

        def fetch_merged_pr_numbers_from_git_remote
          merged_feature_head_sha1s = git(:log, '--merges', '--pretty=format:%P', "origin/#{production_branch}..origin/#{staging_branch}").map do |line|
            main_sha1, feature_sha1 = line.chomp.split /\s+/
            feature_sha1
          end

          git('ls-remote', 'origin', 'refs/pull/*/head').map do |line|
            sha1, ref = line.chomp.split /\s+/

            if merged_feature_head_sha1s.include? sha1
              if %r<^refs/pull/(\d+)/head$>.match ref
                pr_number = $1.to_i

                if git('merge-base', sha1, "origin/#{production_branch}").first.chomp == sha1
                  say "##{pr_number} (#{sha1}) is already merged into #{production_branch}", :debug
                else
                  pr_number
                end
              else
                say "Bad pull request head ref format: #{ref}", :warn
                nil
              end
            end
          end.compact
        end

        def search_issue_numbers(query)
          sleep 1
          say "search issues with query:#{query}", :debug
          # Fortunately, we don't need to take care of the page count in response, because
          # the default value of per_page is 30 and we can't specify more than 30 commits due to
          # the length limit specification of the query string.
          client.search_issues("#{query}")[:items].map(&:number)
        end

        def fetch_squash_merged_pr_numbers_from_github
          # When "--abbrev" is specified, the length of the each line of the stdout isn't fixed.
          # It is just a minimum length, and if the commit cannot be uniquely identified with
          # that length, a longer commit hash will be displayed.
          # We specify this option to minimize the length of the query string, but we use
          # "--abbrev=7" because the SHA syntax of the search API requires a string of at
          # least 7 characters.
          # ref. https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests#search-by-commit-sha
          # This is done because there is a length limit on the API query string, and we want
          # to create a string with the minimum possible length.
          shas = git(:log, '--pretty=format:%h', "--abbrev=7", "--no-merges", "--first-parent",
            "origin/#{production_branch}..origin/#{staging_branch}").map(&:chomp)

          pr_nums = []
          query_base = "repo:#{repository} is:pr is:closed"
          query = query_base
          # Make bulk requests with multiple SHAs of the maximum possible length.
          # If multiple SHAs are specified, the issue search API will treat it like an OR search,
          # and all the pull requests will be searched.
          # This is difficult to read from the current documentation, but that is the current
          # behavior and GitHub support has responded that this is the spec.
          shas.each do |sha|
            # Longer than 256 characters are not supported in the query.
            # ref. https://docs.github.com/en/rest/reference/search#limitations-on-query-length
            if CGI.escape(query).length + 1 + sha.length >= 256
              pr_nums.concat(search_issue_numbers(query))
              query = query_base
            end
            query += " " + sha
          end
          if query != query_base
              pr_nums.concat(search_issue_numbers(query))
          end
          pr_nums
        end

        def create_release_pr(merged_prs)
          found_release_pr = detect_existing_release_pr
          create_mode = found_release_pr.nil?

          if create_mode
            if @dry_run
              release_pr = nil
              changed_files = []
            else
              release_pr = prepare_release_pr
              changed_files = pull_request_files(release_pr)
            end
          else
            release_pr = found_release_pr
            changed_files = pull_request_files(release_pr)
          end

          pr_title, pr_body = if @overwrite_description
                                build_pr_title_and_body(release_pr, merged_prs, changed_files, template_path)
                              else
                                build_and_merge_pr_title_and_body(release_pr, merged_prs, changed_files)
                              end

          if @dry_run
            say 'Dry-run. Not updating PR', :info
            say pr_title, :notice
            say pr_body, :notice
            dump_result_as_json( release_pr, merged_prs, changed_files ) if @json
            return
          end

          update_release_pr(release_pr, pr_title, pr_body)

          say "#{create_mode ? 'Created' : 'Updated'} pull request: #{release_pr.rels[:html].href}", :notice
          dump_result_as_json( release_pr, merged_prs, changed_files ) if @json
        end

        def detect_existing_release_pr
          say 'Searching for existing release pull requests...', :info
          user=repository.split("/")[0]
          client.pull_requests(repository, head: "#{user}:#{staging_branch}", base: production_branch).first
        end

        def prepare_release_pr
          client.create_pull_request(
            repository, production_branch, staging_branch, 'Preparing release pull request...', ''
          )
        end

        def build_and_merge_pr_title_and_body(release_pr, merged_prs, changed_files)
          # release_pr is nil when dry_run && create_mode
          old_body = (release_pr && release_pr.body != nil) ? release_pr.body : ""
          pr_title, new_body = build_pr_title_and_body(release_pr, merged_prs, changed_files, template_path)

          [pr_title, merge_pr_body(old_body, new_body)]
        end

        def update_release_pr(release_pr, pr_title, pr_body)
          say 'Pull request body:', :debug
          say pr_body, :debug

          client.update_pull_request(
            repository, release_pr.number, :title => pr_title, :body => pr_body
          )

          unless labels.empty?
            client.add_labels_to_an_issue(
              repository, release_pr.number, labels
            )
          end
        end

        # Fetch PR files of specified pull_request
        def pull_request_files(pull_request)
          return [] if pull_request.nil?

          # Fetch files as many as possible
          client.auto_paginate = true
          files = client.pull_request_files repository, pull_request.number
          client.auto_paginate = false
          return files
        end
      end
    end
  end
end
