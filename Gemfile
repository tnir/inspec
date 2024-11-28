# TODO: Commentine artifactory source block temporarily
# to addres JIRA #9390 (Chef InSpec  Verify pipeline is failing due to checksum mismatch of mixlib-shellout gem)
# For Chef internal builds, allows preview versions of gems if available.
# if ENV["ARTIFACTORY_BASE_URL"]
#   source ENV["ARTIFACTORY_BASE_URL"] + "/artifactory/api/gems/omnibus-gems-local/" do
#     # TODO: either fully populate this list, or revert back to non-block format
#     #       to sweep all Chef gems from Artifactory.
#     gem "chef-licensing"
#   end
# end

source "https://rubygems.org"

gem "inspec", path: "."

# This dependency is NOT used for normal gem deployment
# - instead, inspec-bin gemspec-depends on inspec
#
# However, AppBundler requires a top-level Gemfile.lock with inspec-bin
# in it in order to package the executable. Hence the odd backwards dependency.
gem "inspec-bin", path: "./inspec-bin"

# ffi version v1.17.0 is breaking verify pipeline as it requires
# rubygems version to be upgraded to >= 3.3.22 Ref:https://buildkite.com/chef/inspec-inspec-main-verify-private/builds/812#018fe177-2ccb-45ed-a25e-213c8a6453df/698-707

gem "ffi", ">= 1.15.5", "< 1.17.0"

# inspec tests depend text output that changed in the 3.10 release
# but our runtime dep is still 3.9+
gem "rspec", ">= 3.10"

group :omnibus do
  gem "rb-readline"
  gem "appbundler"
  gem "ed25519" # ed25519 ssh key support done here as its a native gem we can't put in the gemspec
  gem "bcrypt_pbkdf" # ed25519 ssh key support done here as its a native gem we can't put in the gemspec
end

group :test do
  gem "chefstyle"
  gem "concurrent-ruby"
  gem "json_schemer"
  gem "m"
  gem "minitest-sprint", "~> 1.0"
  gem "minitest", "5.24.1"
  gem "mocha"
  gem "nokogiri"
  gem "pry-byebug"
  gem "pry"
  gem "rake"
  gem "simplecov"
  gem "simplecov_json_formatter"
  gem "webmock"
end

group :deploy do
  gem "inquirer"
end
