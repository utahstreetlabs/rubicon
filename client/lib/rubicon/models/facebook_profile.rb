require 'rubicon/models/profile'
require 'active_support/core_ext/string/starts_ends_with'
require 'timeout'

module Rubicon
  class FacebookProfile < Profile
    include Timeout

    # Returns true if the profile has access token, false otherwise (no secret required)
    def connected?
      token.present?
    end

    # Returns the URL to the profile photo of the requested size (+:square+ or +:large+). For the default type, use
    # +#photo_url# instead.
    #
    # @options option [Integer] :width (+nil+) when +type+ is +:square, adds the +height+ and +width+ params with this
    #                           value to provide a hint as to the size of the image
    def typed_photo_url(type, options = {})
      url = "#{photo_url}?type=#{type}"
      if type == :square && options[:width]
        url << "&height=#{options[:width]}&width=#{options[:width]}"
      end
      url
    end

    def photos
      api_user.photos # memoized internally by Mogli
    end

    def statuses
      api_user.statuses # memoized internally by Mogli
    end

    # returns the current location value set in facebook -
    # potentially different than the value in rubicon if we
    # have not yet synced
    def facebook_location
      api_user.location
    end

    # Syncs the profile by updating from +api_user+.
    def sync_attrs
      begin
        update_from_api!(api_user)
      rescue Exception => e
        logger.warn("Unable to sync facebook profile #{self.uid},person_id=>#{self.person_id}.  Check for corrupted profile: #{e.message}")
      end
    end

    # Return a hash of uids to +Mogli::User+s representing this profile's Facebook friends.
    def fetch_api_followers
      api_user.friends.inject({}) {|m, f| m.merge(f.id => f)}
    end

    # Returns the list of +Mogli::Page+s representing the pages this profile owns. Note that this is not the full set
    # of accounts the profile owns - it does not include any application accounts.
    def pages
      api_user.accounts.reject {|p| p.category == 'Application'}
    end

    # Returns a list of +Rubicon::FacebookPageProfile+s representing the pages this profile owns. If Rubicon does not
    # yet know about a particular page, the profile returned for it will not yet have been persisted.
    def page_profiles
      uids = pages.map(&:id)
      profile_idx = self.class.find_for_uids_and_network(uids, :facebook).inject({}) {|m, p| m.merge(p.uid => p)}
      pages.map do |page|
        profile_idx[page.id] ||
          self.class.new_from_attributes(FacebookPageProfile.attributes_from_api(page, :facebook))
      end
    end

    # Connects and disconnects page profiles based on +flags+. +flags+ is a hash of flags keyed on page profile uid.
    # If a flag is +'1'+ and the corresponding profile does not exist or is not connected, it is created or updated to
    # a connected state. As well, if a block is provided, the page profile will be yielded to the block. If a flag is
    # +'0'+ and the the profile is connected, it is disconnected. Returns a hash of profiles keyed by +connected+ and
    # +disconnected+.
    def update_page_connections!(flags, &block)
      api_pages = pages.inject({}) {|m, p| m.merge(p.id => p)}
      page_profiles.inject({connected: [], disconnected: []}) do |memo, profile|
        api_page = api_pages[profile.uid]
        connect = flags[profile.uid]
        if connect == '1' and (!profile.persisted? or !profile.connected?)
          if profile.persisted?
            profile.person_id = self.person_id
            profile.update_from_api!(api_page)
          else
            profile = Rubicon::Profile.create_from_api!(self.person_id, :facebook, api_page, :page)
          end
          yield(profile) if block_given?
          memo[:connected] << profile
        elsif connect == '0' and profile.persisted? and profile.connected?
          profile.disconnect!
          memo[:disconnected] << profile
        end
        memo
      end
    end

    def create_follow(follower, options = {})
      params = {}
      params[:rank] = follow_rank(follower).to_params unless options[:no_rank]
      super(follower, params)
    end

    def photo_url
      photo_url ||= self.class.photo_url(self.uid)
    end

    def profile_url
      profile_url ||= self.class.profile_url(self.uid)
    end

    def self.photo_url(uid)
      "http://graph.facebook.com/#{uid}/picture"
    end

    def self.profile_url(uid)
      "http://www.facebook.com/profile.php?id=#{uid}"
    end

    def self.redhook_follow_class
      # BACKWARDS COMPATIBILITY: we need to roll with this existing job for facebook friendships,
      # then update redhook to handle two different types, let the queues flush out and then we can roll a new version
      Redhook::Job::AddFriendship
    end

    # Converts +api_user+ into a profile attributes hash.
    def self.attributes_from_api(api_user, options = {})
      {
        'uid' => api_user.id,
        'username' => api_user.username,
        'name' => api_user.name,
        'first_name' => api_user.first_name,
        'last_name' => api_user.last_name,
        'email' => api_user.email,
        'photo_url' => self.photo_url(api_user.id),
        'profile_url' => api_user.link || self.profile_url(api_user.id),
        'gender' => api_user.gender,
        'location' => (api_user.location && api_user.location.name),
        'birthday' => (Date.strptime(api_user.birthday, '%m/%d/%Y') if api_user.birthday)
      }
    end

    # Extracts the Facebook profile URL from an OAuth attributes hash.
    def self.profile_url_from_oauth(oauth, network)
      oauth.fetch('info', {}).fetch('urls', {}).fetch('Facebook', {})
    end

    # Returns whether or not the given email address is an anonymous Facebook email address.
    def self.anonymous_email?(email)
      email.present? && email.ends_with?('proxymail.facebook.com')
    end

    # Enqueues a job to extend the expiration of a facebook auth token in the background
    def self.async_extend_token_expiry(person_id, options = {})
      logger.debug("Enqueuing FacebookExtendTokenExpiry job: #{person_id}")
      Rubicon::Jobs::FacebookExtendTokenExpiry.enqueue(person_id, options)
    end

    # Simple wrapper around the +has_permission?+ mogli call; given an active client, will ask
    # Facebook if the user currently has a permission granted to our app.  Note that
    # profile provides +has_permission?+ which checks if a profile was given a permission
    # at connect time; this checks the live permissions by contacting facebook, because
    # a user could remove a permission remotely from within facebook.
    def has_live_permission?(permission)
      # Raises Timeout::Error on a timeout.  It's the caller's responsibility to determine
      # how they want to handle the timeout.
      timeout(Rubicon.configuration.ext_timeout) do
        api_user.has_permission?(permission)
      end
    end

    # Causes an invitation to be sent to this profile's corresponding Facebook wall. Supported options:
    # message, picture, link, name, caption, description, source. Returns true if the invitation was sent, false
    # otherwise.
    def send_invitation_from(inviter, invite, options = {})
      return false unless inviter.connected?

      # We post from the inviter to the invitee (self), so we want to use the api_client
      # associated with the inviter's tokens.
      begin
        unless post_to_feed(options.merge(client: inviter.api_client))
          # If an error is returned, delete the new invite
          delete_invite(invite)
          return false
        end
      rescue Exception => e
        delete_invite(invite)
        raise e
      end
      true
    end

    def with_mogli_error_handling(client, options)
      begin
        yield
      rescue Mogli::Client::OAuthException => e
        raise MissingPermission if e.message =~ /The user hasn't authorized the application to perform this action/
        raise InvalidSession if e.message =~ /the user changed the password/
        raise ActionNotAllowed if e.message =~ /User not visible/
        # For other Mogli::Client::OAuthExceptions, translate to AccessTokenInvalid
        # Log information about why this operation failed to determine why, for instace, we can't
        # publish to the Facebook ticker.
        logger.info("Unable to post to Facebook: access_token=#{client.access_token}, default_params=#{client.default_params}, url=#{options[:url]}, params=#{options[:params]}, error message=#{e.message}")
        raise AccessTokenInvalid
      rescue Mogli::Client::SessionInvalidatedDueToPasswordChange => e
        raise InvalidSession
      rescue Mogli::Client::HTTPException, Errno::ECONNRESET => e
        unless options[:retry]
          # Attempt to catch transitory issues with Facebook by retrying
          logger.info("#{e.class} raised, attempting retry(uid=>#{self.uid},message=>#{e.message})")
          options[:retry] = true
          retry
        end
        self.class.handle_error("Unable to post to Facebook feed after retry #{self.uid}", e.message, options: options)
        false
      rescue Mogli::Client::FeedActionRequestLimitExceeded => e
        raise RateLimited
      rescue Exception => e
        # This also includes Mogli::Client::OAuthAccessTokenException, which means an access token
        # was missing for the resource required.  Should only result due to a programming error.
        self.class.handle_error("Unable to post to Facebook feed #{self.uid}", e, options: options)
        false
      end
    end

    def facebook_post(options = {})
      options = options.dup
      client = (options.delete(:client) || api_client)
      with_mogli_error_handling(client, options) do
        client.post(options[:url], "Post", options[:params])
      end
    end

    def facebook_delete(options = {})
      options = options.dup
      client = (options.delete(:client) || api_client)
      with_mogli_error_handling(client, options) do
        client.delete(options[:url])
      end
    end

    def post_to_feed(options = {})
      known_keys = [:message, :picture, :link, :name, :caption, :description, :source, :actions, :ref]
      options = options.dup
      options.merge!(url: "/#{self.uid}/feed",
        params: options.reject {|key, _| !known_keys.include?(key.to_sym)})
      facebook_post(options)
    end

    def post_to_ticker(options = {})
      known_keys = [:client, :params, :url, :message, :to, :profile]
      params = {options[:object] => options[:link]}
      # Add additional open graph-recognized parameters here as necessary.  See:
      # http://developers.facebook.com/docs/reference/api/post/
      [:message, :to, :profile].each do |p|
        params.merge!(p => options[p]) if options[p].present?
      end
      params.merge!(options.fetch(:params, {}))
      options.merge!(params: params,
        url: "/#{self.uid}/#{options[:namespace]}:#{options[:action]}")
      facebook_post(options.reject {|key, _| !known_keys.include?(key.to_sym)})
    end

    # @param [String] :app_access_token special app access token that does not change unless the Copious
    #   app secret is changed.  Required for making an app to user (a2u) posting, such as a notification.
    # For full docs on the Notifications API see: https://developers.facebook.com/docs/app-notifications/
    # @option options [String] :template template/text for notification
    # @option options [String] :href target URL displayed in jewel
    # @option options [String] :ref used to separate notifications into groups for insight tracking.
    def post_notification(options = {})
      options = options.dup
      client = (options.delete(:client) || api_client)
      params = { access_token: Rubicon.configuration.facebook_access_token }
      params[:template] = options.delete(:template) if options[:template]
      params[:href] = options.delete(:href) if options[:href]
      params[:ref] = options.delete(:ref) if options[:ref]
      url = "#{self.uid}/notifications"
      with_mogli_error_handling(client, options) do
        client.post(url, "Post", params)
      end
    end

    def extend_token_expiry(options = {})
      attrs = {}
      begin
        response = Mogli::Client.exchange_access_token_as_application(Rubicon.configuration.facebook_consumer_key,
          Rubicon.configuration.facebook_consumer_secret, self.token)
        response.symbolize_keys!
        if response[:access_token]
          attrs['token'] = response[:access_token]
          if response[:expires]
            attrs['oauth_expiry'] = response[:expires].from_now.utc.to_datetime
          else
            logger.warn("Facebook returned token=>#{self.token} without expiration")
          end
        end
      rescue Exception => e
        self.class.handle_error("Unable to get new access token #{self.uid}", e, options: options)
      end
      self.update_attributes!(attrs)
    end

    def feed_postable?
      connected?
    end
    alias :og_postable? :feed_postable?

  protected
    def api_client(options = {})
      @api_client ||= Mogli::Client.new(options.fetch(:token, self.token))
    end

    def api_user(options = {})
      @api_user ||= Mogli::User.find("me", api_client(options))
      unless @api_user.present?
        raise MissingUserData
      end
      @api_user
    end
  end
end
