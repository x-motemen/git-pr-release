require 'webmock/rspec'

WebMock.disable_net_connect!

require 'vcr'

VCR.configure do |c|
  c.configure_rspec_metadata!

  c.cassette_library_dir = 'spec/vcr_cassettes'

  c.hook_into :webmock

  c.filter_sensitive_data('<TOKEN>') do
    test_github_token
  end
  c.filter_sensitive_data('<GITHUB_ENTERPRISE_HOST>') do
    test_github_enterprise_host
  end
  c.filter_sensitive_data('<USER>') do
    test_github_user
  end
  c.filter_sensitive_data('<PROJECT>') do
    test_github_project
  end
end


def test_github_token
  ENV['GIT_PR_RELEASE_TOKEN']
end

def test_github_enterprise_host
  ENV['GIT_PR_RELEASE_TEST_GITHUB_ENTERPRISE_HOST']
end

def test_github_user
  ENV['GIT_PR_RELEASE_TEST_GITHUB_USER'] || 'motemen'
end

def test_github_project
  ENV['GIT_PR_RELEASE_TEST_GITHUB_PROJECT'] || 'sandbox'
end
