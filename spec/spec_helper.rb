require "timecop"
require "yaml"
require "git/pr/release"
require "webmock/rspec"

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed

  config.around(:each) do |example|
    begin
      ENV['TZ'], old = 'Asia/Tokyo', ENV['TZ']
      example.run
    ensure
      ENV['TZ'] = old
    end
  end

  config.after do
    Timecop.return
  end

  # Trigger Autoload
  Octokit::Client
end

Dir[File.expand_path("support/**/*.rb", __dir__)].each {|f| require f }
