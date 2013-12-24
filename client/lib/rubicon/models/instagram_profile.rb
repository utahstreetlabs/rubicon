require 'rubicon/models/profile'
require 'instagram'

module Rubicon
  class InstagramProfile < Profile
    # Returns true if the profile has access token, false otherwise (no secret required)
    def connected?
      token.present?
    end

    # Fetch photos from an instagram users most recent media feed.
    # @param [Hash] options options used to fetch user's recent media
    # @option options [Integer] :count Number of photos to fetch
    # @option options [Integer] :max_id Max ID of photo to fetch; greater values indicate more recent
    # @return [Hash] hash mapping photo ids to photo objects
    def photos(options = {})
      client = api_client

      count = options.fetch(:count, 20)
      # Initial starting value for max_id, if any.
      max_id = options.fetch(:max_id, nil)

      api_recent_media = Hash[1.step(count,20).inject([]) do |acc, a|
        if (count > 20)
          options = {count: 20}
          count -= 20
        else
          options = {count: count}
          count = 0
        end
        options = {max_id: max_id}.merge(options) if max_id
        begin
          response = client.user_recent_media(options)
          max_id = response['data'].last['id'].to_i if response['data'].last
          acc + response['data'].map {|u| [u['id'], u]}
        rescue Instagram::Error => e
          # On error just return the accumulator and keep processing
          logger.error("Received error #{e.message} from Instagram; continuing.")
          acc
        end
      end]
    end

    def photo_size_url(photo, version)
      photo.fetch('images', {}).fetch(version.to_s, {}).fetch('url', '')
    end

    def followers_count(options = {})
      client = api_client
      client.user.fetch("counts", {}).fetch("followed_by", 0)
    end

    def connection_count
      api_follows_count != 0 ? api_follows_count : super
    end

    def profile_url
      nil
    end

    def sync_attrs
      begin
        update_from_api!(api_user)
      rescue Exception => e
        logger.warn("Unable to sync instagram profile #{self.uid},person_id=>#{self.person_id}.  Check for corrupted profile: #{e.message}")
      end
    end

    # Return the list of follower profiles that Instagram
    # knows about.
    def fetch_api_followers
      client = api_client

      next_cursor = nil
      api_followers = Hash[1.step(self.followers_count,20).inject([]) do |acc, a|
        options = {count: 20}
        {cursor: next_cursor}.merge!(options) if next_cursor
        response = client.user_followed_by(self.uid, options)
        next_cursor = response.fetch('pagination', {}).fetch('next_cursor', nil)
        acc + response['data'].map {|u| [u['id'], u]}
      end]
    end

    ###
    ### Class methods
    ###

    # Returns an attributes hash constructed by examining a Instagram API object.
    def self.attributes_from_api(api_attrs, options = {})
      attrs = {}
      attrs['uid'] = api_attrs['id']
      attrs['username'] = api_attrs['username']
      attrs['name'] = api_attrs['full_name']
      unless attrs['name'].present?
        attrs['name'] = api_attrs['username']
      end
      attrs['photo_url'] = api_attrs['profile_picture']
      attrs
    end

    # Returns an attributes hash for Instagram constructed by examining an OAuth data hash.
    def self.attributes_from_oauth(oauth, network)
      attrs = super
      attrs['secure'] = oauth.fetch('secure', nil)
      info = oauth.fetch('info', {})
      attrs['username'] = info.fetch('nickname', "")
      unless attrs['name'].present?
        attrs['name'] = (attrs['first_name'].present? || attrs['last_name'].present?) ? 
          "#{attrs['first_name']} #{attrs['last_name']}" : attrs['username']
      end
      attrs['photo_url'] = info.fetch('image', "")
      attrs
    end

    protected

    def api_user(options = {})
      @api_user ||= api_client(options).user
      unless @api_user.present?
        raise MissingUserData
      end
      @api_user
    end

    def api_client(options = {})
      unless @api_client
        client_id = self.secure ?
          Rubicon.configuration.instagram_consumer_key_secure :
          Rubicon.configuration.instagram_consumer_key
        client_secret = self.secure ?
          Rubicon.configuration.instagram_consumer_secret_secure :
          Rubicon.configuration.instagram_consumer_secret
        token = options.fetch(:token, self.token)
        @api_client = ::Instagram::Client.new(client_id: client_id,
                                         client_secret: client_secret,
                                         access_token: token)
        raise Exception.new("Could not create instagram client") unless @api_client
      end
      @api_client
    end
  end
end
