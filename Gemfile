# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "brute",      path: "../brute"
gem "brute_flow", path: "../brute_flow"
gem "bpmn"

# Falcon requires native openssl — install separately when deploying:
#   gem install falcon
# gem "falcon", "~> 0.48"

group :maintenance, optional: true do
	gem "utopia-project"
	gem "bake-gem"
	gem "bake-modernize"
	gem "bake-releases"
end
