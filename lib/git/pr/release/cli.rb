require 'octokit'
require 'optparse'

module Git
  module Pr
    module Release
      class CLI
        include Git::Pr::Release::Util
        attr_reader :repository, :production_branch, :staging_branch

        def self.start
          result = self.new.start
          exit result
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
          exit_code = create_release_pr(merged_prs)
          return exit_code
        end

        def client
          @client ||= Octokit::Client.new :access_token => obtain_token!
        end

        def configure
          host, @repository, scheme = host_and_repository_and_scheme

          if host
            # GitHub:Enterprise
            OpenSSL::SSL.const_set :VERIFY_PEER, OpenSSL::SSL::VERIFY_NONE # XXX

            Octokit.configure do |c|
              c.api_endpoint = "#{scheme}://#{host}/api/v3"
              c.web_endpoint = "#{scheme}://#{host}/"
            end
          end

          @production_branch = ENV.fetch('GIT_PR_RELEASE_BRANCH_PRODUCTION') { git_config('branch.production') } || 'master'
          @staging_branch    = ENV.fetch('GIT_PR_RELEASE_BRANCH_STAGING') { git_config('branch.staging') }       || 'staging'

          say "Repository:        #{repository}", :debug
          say "Production branch: #{production_branch}", :debug
          say "Staging branch:    #{staging_branch}", :debug
        end

        def fetch_merged_prs
          git :remote, 'update', 'origin' unless @no_fetch

          merged_feature_head_sha1s = git(
            :log, '--merges', '--pretty=format:%P', "origin/#{production_branch}..origin/#{staging_branch}"
          ).map do |line|
            main_sha1, feature_sha1 = line.chomp.split /\s+/
            feature_sha1
          end

          merged_pull_request_numbers = git('ls-remote', 'origin', 'refs/pull/*/head').map do |line|
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

          merged_prs = merged_pull_request_numbers.map do |nr|
            pr = client.pull_request repository, nr
            say "To be released: ##{pr.number} #{pr.title}", :notice
            pr
          end

          merged_prs
        end

        def create_release_pr(merged_prs)
          say 'Searching for existing release pull requests...', :info
          found_release_pr = client.pull_requests(repository).find do |pr|
            pr.head.ref == staging_branch && pr.base.ref == production_branch
          end
          create_mode = found_release_pr.nil?

          # Fetch changed files of a release PR
          changed_files = pull_request_files(client, found_release_pr)

          if @dry_run
            pr_title, new_body = build_pr_title_and_body found_release_pr, merged_prs, changed_files
            pr_body = create_mode ? new_body : merge_pr_body(found_release_pr.body, new_body)

            say 'Dry-run. Not updating PR', :info
            say pr_title, :notice
            say pr_body, :notice
            dump_result_as_json( found_release_pr, merged_prs, changed_files ) if @json
            return 0
          end

          pr_title, pr_body = nil, nil
          release_pr = nil

          if create_mode
            created_pr = client.create_pull_request(
              repository, production_branch, staging_branch, 'Preparing release pull request...', ''
            )
            unless created_pr
              say 'Failed to create a new pull request', :error
              return 2
            end
            changed_files = pull_request_files(client, created_pr) # Refetch changed files from created_pr
            pr_title, pr_body = build_pr_title_and_body created_pr, merged_prs, changed_files
            release_pr = created_pr
          else
            pr_title, new_body = build_pr_title_and_body found_release_pr, merged_prs, changed_files
            pr_body = merge_pr_body(found_release_pr.body, new_body)
            release_pr = found_release_pr
          end

          say 'Pull request body:', :debug
          say pr_body, :debug

          updated_pull_request = client.update_pull_request(
            repository, release_pr.number, :title => pr_title, :body => pr_body
          )

          unless updated_pull_request
            say 'Failed to update a pull request', :error
            return 3
          end

          exit_code = set_labels_to_release_pr(release_pr)
          return exit_code if exit_code != 0

          say "#{create_mode ? 'Created' : 'Updated'} pull request: #{updated_pull_request.rels[:html].href}", :notice
          dump_result_as_json( release_pr, merged_prs, changed_files ) if @json

          return 0
        end

        def set_labels_to_release_pr(release_pr)
          labels = ENV.fetch('GIT_PR_RELEASE_LABELS') { git_config('labels') }
          if not labels.nil? and not labels.empty?
            labels = labels.split(/\s*,\s*/)
            labeled_pull_request = client.add_labels_to_an_issue(
              repository, release_pr.number, labels
            )

            unless labeled_pull_request
              say 'Failed to add labels to a pull request', :error
              return 4
            end
          end

          return 0
        end
      end
    end
  end
end
