require 'rubicon/models/profile'
require 'tumblife'

module Rubicon
  class TumblrProfile < Profile
    # Followers are blog-specific in tumblr.  A user can have many blogs
    def followers_count(options = {})
      client = api_client
      # Returns the followers count for an authenticated person.
      client.followers("#{self.primary_blog['name']}.tumblr.com", limit: 1)['total_users'].to_i
    end

    # Return the list of follower profiles that Tumblr
    # knows about.  Followers in tumblr are blog-specific.  While a user
    # has a primary blog (which is the blog they created at time of signup)
    # there is no way for a user to change which blog is their primary one.
    # For now, we're going to just have this return followers for the primary
    # blog because there's a one-to-one ratio of users to primary blogs.  They're
    # personal.  We may expand this to return followers of any blog a user
    # can post to in the future if we want to gather more data.
    def fetch_api_followers
      client = api_client

      api_followers = Hash[1.step(self.followers_count,20).inject([]) do |acc, a|
        acc + client.followers("#{self.primary_blog['name']}.tumblr.com", limit: 20, offset: acc.length)['users'].map {|u| [u['name'], u]}
      end]
    end

    def sync_attrs
      begin
        update_from_api!(self.api_user)
      rescue Exception => e
        logger.warn("Unable to sync tumblr profile #{self.uid},person_id=>#{self.person_id}.  Check for corrupted profile: #{e.message}")
      end
    end

    ###
    ### Class methods
    ###

    # Returns an attributes hash constructed by examining a Tumblr API object.
    def self.attributes_from_api(api_attrs, options = {})
      attrs = {}
      attrs['uid'] = api_attrs['user']['name']
      attrs['username'] = api_attrs['user']['name']
      attrs['name'] = api_attrs['user']['name']
      primary_blog = api_attrs['user']['blogs'].detect {|b| !!b['primary']}
      attrs['profile_url'] = primary_blog ? primary_blog['url'] : nil
      attrs
    end

    def self.profile_url_from_oauth(oauth, network)
      oauth.fetch('info', {}).fetch('urls', {}).fetch('website', {})
    end

    protected

    def api_client(options = {})
      unless @api_client
        consumer = OAuth::Consumer.new(Rubicon.configuration.tumblr_consumer_key,
          Rubicon.configuration.tumblr_consumer_secret, site: 'http://api.tumblr.com')
        token = options.fetch(:token, self.token)
        secret = options.fetch(:secret, self.secret)
        access_token = OAuth::AccessToken.new(consumer, token, secret)
        @api_client = Tumblife.new(access_token)
      end
      @api_client
    end

    # Fetches the user info for a tumblr user.  This contains
    # all the blogs they have permission to post to, their username,
    # and several other things.
    def api_user(options = {})
      @api_user ||= api_client(options).info_user
      unless @api_user.present?
        raise MissingUserData
      end
      @api_user
    end

    # Fetches information about all the blogs a tumblr user has
    # permission to post to
    def primary_blog
      @primary_blog ||= self.api_user['user']['blogs'].detect {|b| !!b['primary']}
    end
  end
end
