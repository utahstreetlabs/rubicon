require 'rubicon/models/profile'
require 'twitter'

module Rubicon
  class TwitterProfile < Profile
    def first_name
      name.split(' ').first if name
    end

    def last_name
      name.split(' ').last if name
    end

    def connection_count
      api_follows_count != 0 ? api_follows_count : super
    end

    def sync_attrs
      begin
        update_from_api!(api_user)
      rescue Exception => e
        logger.warn("Unable to sync twitter profile #{self.uid},person_id=>#{self.person_id}.  Check for corrupted profile: #{e.message}")
      end
    end

    # Return the list of follower profiles that Twitter
    # knows about.  Twitter returns 100 followers at a time
    # so we fetch them in chunks and then return the full
    # hash of all followers back to the caller.
    def fetch_api_followers
      client = api_client

      # Return value
      follower_ids = client.follower_ids.ids || []
      api_followers = Hash[follower_ids.each_slice(100).inject([]) do |acc, a|
        acc + client.users(a).map {|u| [u['id'].to_i, u]}
      end]
    end

    # Updates the user's Twitter status.
    # @option options [String] :text the text of the status update, up to 140 characters
    def post_to_feed(options = {})
      text = options[:text] or raise ArgumentError.new("text option not provided")
      client = options.delete(:client) || api_client
      begin
        client.update(options[:text])
        true
      rescue Exception => e
        self.class.handle_error("Unable to update Twitter status #{self.uid}", e, options: options)
        false
      end
    end

    def feed_postable?
      connected?
    end

    ###
    ### Class methods
    ###

    # Normalizes a Twitter::Client data hash into a rubicon attributes hash.
    def self.attributes_from_api(api_attrs, options = {})
      attrs = {}
      attrs['uid'] = api_attrs['id']
      attrs['username'] = api_attrs['screen_name']
      attrs['name'] = api_attrs['name']
      # as of 1/17/2012, the url reported by the twitter api is the one the twitter sets as an attribute of his
      # twitter profile, *not* the url to the user's profile on twitter.com. the latter is what we want, so we
      # synthesize it here. will break if they ever change their site's url structure.
      # attrs['profile_url'] = api_attrs['url']
      attrs['profile_url'] = "https://twitter.com/#{api_attrs['screen_name']}"
      attrs['photo_url'] = api_attrs['profile_image_url']
      attrs['api_follows_count'] = api_attrs['followers_count']
      attrs
    end

    # Returns an attributes hash for Twitter constructed by examining an OAuth data hash.
    def self.attributes_from_oauth(oauth, network)
      attrs = super
      info = oauth.fetch('info', {})
      attrs['username'] = info.fetch('nickname', nil)
      attrs
    end

    protected

    def api_user(options = {})
      @api_user ||= api_client(options).current_user
      unless @api_user.present?
        raise MissingUserData
      end
      @api_user
    end

    def api_client(options = {})
      unless @api_client
        token = options.fetch(:token, self.token)
        secret = options.fetch(:secret, self.secret)
        @api_client = ::Twitter::Client.new(consumer_key: Rubicon.configuration.twitter_consumer_key,
                                            consumer_secret: Rubicon.configuration.twitter_consumer_secret,
                                            oauth_token: token,
                                            oauth_token_secret: secret)
        raise Exception.new("Could not create twitter client") unless @api_client
        raise Exception.new("Must be authenticated") unless @api_client.verify_credentials
        raise Exception.new("Twitter API client rate limited") unless @api_client.rate_limit_status.remaining_hits > 0
      end
      @api_client
    end
  end
end
