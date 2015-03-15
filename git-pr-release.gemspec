# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "git-pr-release"
  spec.version       = '0.1.3'
  spec.authors       = ["motemen"]
  spec.email         = ["motemen@gmail.com"]
  spec.summary       = 'Creates a release pull request'
  spec.description   = 'git-pr-release creates a pull request which summarizes feature branches that are to be released into production'
  spec.homepage      = 'https://github.com/motemen/git-pr-release'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'octokit',  '~> 2.7'
  spec.add_dependency 'highline', '~> 1.6'
  spec.add_dependency 'colorize', '~> 0.6'
  spec.add_dependency 'diff-lcs', '~> 1.2'

  spec.license = 'MIT'
end
