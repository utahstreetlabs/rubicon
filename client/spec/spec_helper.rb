require 'rubygems'
require 'bundler'
require 'yaml'

# Bundler >= 1.0.10 uses Psych YAML, which is broken, so fix that.
# https://github.com/carlhuda/bundler/issues/1038
YAML::ENGINE.yamler = 'syck'

Bundler.setup :default, :test
ENV['RACK_ENV'] = 'test'

Bundler.setup

require 'mocha'
require 'rspec'
require 'timecop'
require 'ladon'
require 'rubicon'
require 'rubicon/resource/base'

Ladon.hydra = Typhoeus::Hydra.new
Ladon.logger = Logger.new('/dev/null')

Rubicon::Resource::Base.base_url = 'http://localhost:4031'

RSpec.configure do |config|
  config.mock_with :mocha
end

Rubicon.configure do |config|
  config.twitter_consumer_key = 'dummyconsumerkey'
  config.twitter_consumer_secret = 'dummyconsumersecret'

  config.tumblr_consumer_key = 'dummyconsumerkey'
  config.tumblr_consumer_secret = 'dummyconsumersecret'

  config.instagram_consumer_key = 'dummyconsumerkey'
  config.instagram_consumer_secret = 'dummyconsumersecret'

  config.instagram_consumer_key_secure = 'dummyconsumerkey_secure'
  config.instagram_consumer_secret_secure = 'dummyconsumersecret_secure'
end
