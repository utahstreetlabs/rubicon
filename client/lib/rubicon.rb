require 'ladon'
require 'ostruct'
require 'redhook'

require 'rubicon/models/profile'
require 'rubicon/models/invite'
require 'rubicon/models/facebook_profile'
require 'rubicon/models/facebook_page_profile'
require 'rubicon/models/twitter_profile'
require 'rubicon/models/tumblr_profile'
require 'rubicon/models/instagram_profile'
require 'rubicon/version'
require 'rubicon/resource/profiles'
require 'rubicon/resource/invites'
require 'rubicon/resource/root'
require 'rubicon/jobs/sync_base'
require 'rubicon/jobs/facebook_extend_token_expiry_job'

module Rubicon
  class Configuration
    # Twitter; uses oauth
    attr_accessor :twitter_consumer_key
    attr_accessor :twitter_consumer_secret

    # Tumblr; uses oauth
    attr_accessor :tumblr_consumer_key
    attr_accessor :tumblr_consumer_secret

    # Instagram; uses oauth
    attr_accessor :instagram_consumer_key
    attr_accessor :instagram_consumer_secret

    # Instagram secure; uses oauth, consumer key and secret used
    # when connecting via ssl
    attr_accessor :instagram_consumer_key_secure
    attr_accessor :instagram_consumer_secret_secure

    # Facebook; uses oauth
    attr_accessor :facebook_consumer_key
    attr_accessor :facebook_consumer_secret
    attr_accessor :facebook_access_token

    attr_accessor :follow_rank

    attr_accessor :ext_timeout
    attr_accessor :flyingdog_enabled

    def initialize
      @follow_rank = OpenStruct.new(facebook: OpenStruct.new(
        shared_connections_coefficient: 1,
        network_affinity_coefficient: 1,
        photo_tags_minimum: 2,
        photo_tags_coefficient: 1,
        photo_annotations_window: 90,
        photo_annotations_coefficient: 1,
        status_annotations_window: 30,
        status_annotations_coefficient: 1
      ))
      @ext_timeout = 5
    end
  end
end

module Rubicon
  class << self
    attr_accessor :configuration

    # Call this method to modify defaults in your initializers.
    #
    # @example
    #   Rubicon.configure do |config|
    #     config.twitter_consumer_key = '1234567890abcdef'
    #     config.twitter_consumer_secret  = '1234567890abcdef'
    #   end
    def configure
      self.configuration ||= Rubicon::Configuration.new
      yield(self.configuration)
    end

    def logger
      Ladon.logger
    end
  end
end
