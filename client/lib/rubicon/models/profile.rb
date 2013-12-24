require 'ladon/model'
require 'rubicon/exceptions'
require 'rubicon/models/follow'
require 'rubicon/models/invite'
require 'rubicon/resource/profiles'
require 'flying_dog/models/identity'

module Rubicon
  class Profile < Ladon::Model
    attr_symbol :network, :type

    attr_accessor :followers, :invites, :token, :secret, :scope
    attr_datetime :oauth_expiry

    def initialize(attrs = {})
      attrs = Hashie::Mash.new(attrs)
      invites = attrs.delete(:invites) || []
      unused = [:_type]
      unused += [:token, :scope, :secret] if Rubicon.configuration.flyingdog_enabled
      unused.each { |k| attrs.delete(k) }
      super(attrs)
      @invites = invites.map { |iattrs| Invite.new(iattrs.merge("invitee_id" => self.id)) }
    end

    # XXX: eventually any method that requires a token, secret, or scope shouldn't be in rubicon
    def identity
      @identity = FlyingDog::Identity.find_by_provider_id(self.network, self.uid) unless defined?(@identity)
      @identity
    end

    # XXX: eventually any method that requires a token, secret, or scope shouldn't be in rubicon
    def token
      if Rubicon.configuration.flyingdog_enabled
        identity && identity.token
      else
        @token
      end
    end

    # XXX: eventually any method that requires a token, secret, or scope shouldn't be in rubicon
    def scope
      if Rubicon.configuration.flyingdog_enabled
        identity && identity.scope
      else
        @scope
      end
    end

    # XXX: eventually any method that requires a token, secret, or scope shouldn't be in rubicon
    def secret
      if Rubicon.configuration.flyingdog_enabled
        identity && identity.secret
      else
        @secret
      end
    end

    # Creates an invite for this profile from +inviter+ based on the provided attributes hash.
    def create_invite_from(inviter, attrs = {})
      invite = Invite.create(self.id, inviter.id, attrs)
      @invites << invite
      invite
    end

    # Deletes a specific invite for this profile.
    def delete_invite(invite)
      Invite.delete_from(self.id, invite.inviter_id)
      @invites.delete(invite)
    end

    def invited_by?(profile_id)
      !invite_by(profile_id).nil?
    end

    def invited?
      invites.any?
    end

    def invite_by(profile_id)
      invites.detect {|invite| invite.inviter_id == profile_id}
    end

    def inviters
      Invite.inviters(self)
    end

    def inviting
      data = Profiles.fire_get(Profiles.profile_inviting_url(self.id), default_data: {'profiles' => []})
      data['profiles'].map {|attrs| Profile.new_from_attributes(attrs)}
    end

    def inviting_count
      inviting.count
    end

    def connection_count
      # if the attribute value is nil, default to whatever the social service reported as follows count
      read_attribute(:connection_count) || api_follows_count
    end

    # Returns true if the profile has access token and secret, false otherwise.
    def connected?
      token.present? && secret.present?
    end

    # Returns true if the profile is connected.
    def can_disconnect?
      connected?
    end

    # Given a set of credentials, validate the new credentials.  If the oauth token
    # passed into this function is the same as the one stored for the profile, assume the
    # credentials are valid, otherwise try to use the passed in token to authenticate to
    # the external network.
    def valid_credentials?(oauth)
      token = self.class.token_from_oauth(oauth)
      secret = self.class.secret_from_oauth(oauth)
      valid = false
      begin
        if token.present?
          if secret.present?
            # Both token and secret must match.
            if (token == self.token) && (secret == self.secret)
              valid = true
            else
              user_info = self.api_user(token: token, secret: secret)
              valid = true if user_info && (self.class.attributes_from_api(user_info)['uid'].to_s == self.uid.to_s)
            end
          else
            # Only token has to match.
            if token == self.token
              valid = true
            else
              user_info = self.api_user(token: token)
              valid = true if user_info && (self.class.attributes_from_api(user_info)['uid'].to_s == self.uid.to_s)
            end
          end
        else
          # If we have no token or secret, just pass true back, nothing to validate
          valid = true
        end
      rescue Exception => e
        # Could be any number of exceptions, including Mogli::Client::OAuthException.
        logger.warn("Credentials for (profile=>#{self.id}, network=>#{self.network} invalid: #{e.message}")
      end
      valid
    end

    # Persists updates to the profile's attributes based on an OAuth data hash. Returns true if successful, false
    # otherwise.
    def update_from_oauth!(oauth, person_id = nil)
      attributes = self.class.attributes_from_oauth(oauth, self.network)
      attributes[:person_id] = person_id if person_id
      # On an update of attributes, merge the requested scope into the existing scope (allows
      # us to just request an additional single permission if we want and still store the
      # total permissions we've asked for.  Useful for Facebook).
      if attributes['scope'].present? and self.scope.present?
        attributes['scope'] = (scope_array(attributes['scope']) + scope_array(self.scope)).compact.uniq.join(',')
      end
      self.update_attributes!(attributes)
    end

    # Persists updates to the profile's attributes based on a social network API object. Returns true if successful,
    # false otherwise.
    def update_from_api!(api_attrs)
      attrs = self.class.attributes_from_api(api_attrs, self.network).merge(synced_at: Time.now.utc)
      self.update_attributes!(attrs)
    end

    def update_attribute!(attr, value)
      self.send("#{attr}=", value)
      self.update!
    end

    def update_attributes!(attrs = {})
      # Do not update oauth credentials if expiration time present in both stored and new
      # attributes and new credentials expire before old ones.
      attrs.delete('oauth_expiry') if credentials_expire_after?(attrs['oauth_expiry'])
      self.attributes = attrs
      self.update!
    end

    # Disconnects the profile by throwing away the OAuth access token and secret. Returns true if successful, false
    # otherwise.
    def disconnect!
      !!Profiles.fire_put(Profiles.profile_url(self.id), token: nil, secret: nil, scope: nil)
    end

    # Removes any data from the profile that makes it look like a registered user
    def unregister!
      Profiles.fire_delete(Profiles.profile_registration_url(self.id), raise_on_error: true)
    end

    def followed_by?(follower)
      !!Follow.find_by_followee_and_follower(self, follower)
    end

    def follows_in(profiles)
      return [] unless profiles.any?
      options = {
        uids: profiles.map(&:id),
        params_map: {uids: :uid},
        default_data: {'profiles' => []}
      }
      data = Profiles.fire_get(Profiles.profile_followers_url(self.id, options))
      data['profiles'].map {|attrs| Profile.new_from_attributes(attrs)}
    end

    def create_follow(follower, options = {})
      Follow.create(self, follower, options)
    end

    def delete_follow(follower)
      Follow.destroy(self, follower)
    end

    def follows
      @follows ||= Follow.find_all_by_followee(self)
    end

    def followers(options = {})
      options = options.reverse_merge(default_data: {'profiles' => []},
        params_map: {limit: :limit, rank: :rank, onboarded_only: :onboarded_only})
      data = Profiles.fire_get(Profiles.profile_followers_url(self.id), options)
      data['profiles'].map {|attrs| Profile.new_from_attributes(attrs)}
    end

    def following
      data = Profiles.fire_get(Profiles.profile_following_url(self.id), default_data: {'profiles' => []})
      data['profiles'].map {|attrs| Profile.new_from_attributes(attrs)}
    end

    UNINVITED_FOLLOWERS_PARAMS = {
      fields: :'fields[]',
      random: :random,
      limit: :limit,
      offset: :offset,
      name: :name
    }
    def uninvited_followers(options = {})
      url = Profiles.profile_followers_uninvited_url(self.id)
      default_data = {'profiles' => []}
      params = {}
      params[:'fields[]'] = options[:fields] if options[:fields]
      UNINVITED_FOLLOWERS_PARAMS.each do |o, p|
        params[p] = options[o] if options[o]
      end
      data = Profiles.fire_get(url, default_data: default_data, params: params)
      data['profiles'].map {|attrs| Profile.new_from_attributes(attrs)}
    end

    # Given a profile (followee_profile), return the set of profiles that has invited us and
    # are also a follower of the followee profile.  Used for pile on invitations:
    # For an invite suggestion, that suggestion is rendered as a pile on if the suggestion has current
    # outstanding invitations from any of the viewer's friends.
    def inviters_following(followee_profile_or_id)
      followee_id = followee_profile_or_id.is_a?(Profile) ? followee_profile_or_id.id : followee_profile_or_id
      data = Profiles.fire_get(Profiles.profile_inviters_following_url(self.id, followee_id), default_data: {'profiles' => []})
      data['profiles'].map {|attrs| Profile.new_from_attributes(attrs)}
    end

    # Computes and returns a +FollowRank+ for +follower+'.
    def follow_rank(follower)
      FollowRank.compute(self, follower)
    end

    # Synchronizes the profile with its equivalent in the external network. The default implementation
    # simply updates the last time the profile was synced.
    def sync_attrs
      raise NotImplementedError
    end

    def fetch_api_followers
      raise NotImplementedError
    end

    # Causes an invitation to be sent to this profile's corresponding external network profile through that network's
    # API. Returns true if the invitation was sent, false otherwise. Must be overridden by subclasses.
    def send_invitation_from(inviter, invite, options = {})
      raise NotImplementedError
    end

    # Posts a message to the corresponding network profile through that network's API. Returns true if the post was
    # successful, false otherwise. Must be overridden by subclasses.
    def post_to_feed(options)
      raise NotImplementedError
    end

    def feed_postable?
      false
    end

    # Sync this profile's connections with what we already know about in Rubicon
    def sync(attrs = {}, &block)
      raise Exception.new("Must be connected") unless self.connected?

      sync_attrs

      api_followers = fetch_api_followers

      # remove follows that don't exist in the api anymore
      self.followers.each do |follower|
        delete_follow(follower) unless api_followers.key?(follower.uid)
      end

      # create follows that have been added in the api if necessary
      api_followers.each do |uid, attrs|
        follower = find_or_create_follower_profile(uid, attrs, &block)
        if follower
          unless followed_by?(follower)
            unless create_follow(follower)
              logger.error("Failed to create follow from profile #{follower.id} to #{self.id}")
            end
          end
        else
          logger.error("Could not find #{network} follower profile with uid #{uid}")
        end
      end

      logger.info("Synced #{api_followers.count} followers for #{network} profile #{self.id}")

      api_followers.count
    end

    def find_or_create_follower_profile(uid, attrs, &block)
      follower_profile = self.class.find_for_uid_and_network(uid, self.network)
      if follower_profile
        # Update follower_profile with latest api attrs.
        follower_profile.update_from_api!(attrs)
      else
        # If we have a block, call it to create a new person in the database.
        follower_person_id = block_given?? yield : nil

        # Create new profile.
        follower_profile = self.class.create_from_api!(follower_person_id, self.network, attrs)
        logger.error("Unable to create profile for network #{self.network} with attrs #{attrs.inspect}") unless
          follower_profile
      end
      follower_profile
    end

    def permission_set
      @permission_set ||= Set.new((self.scope || '').split(%r{,\s*}).map(&:to_sym))
    end

    # A scope is a group of permissions.  Stored as a csv as part of a user's profile.
    def has_permission?(permission)
      permission_set.member?(permission.to_sym)
    end

    # Checks a remote network to see if a user currently has a permission active
    # for a profile.  Must be overridden by subclasses, which implement how a profile
    # communicates with a network to check the state of a permission.
    def has_live_permission?(permission)
      raise NotImplementedError
    end

    # Given a set of permissions, fetch from the network which
    # are not currently granted to a Facebook user.
    def missing_live_permissions(permissions)
      return [] unless permissions.any?
      permissions.select { |p| !self.has_live_permission?(p) }
    end

    # Updates an instance of +Profile+. Returns true if successful, false otherwise.
    def update!
      return true unless self.changed?
      attrs = self.attributes.merge(person_id: self.person_id, network: self.network.to_s)
      !!Profiles.fire_put(Profiles.profile_url(self.id), attrs)
    end

    ###
    ### Class methods
    ###

    # Creates an instance of +Profile+ based on an OAuth data hash. Returns true if successful, false otherwise.
    def self.create_from_oauth!(person_id, network, oauth)
      clazz = profile_class(network)
      clazz.create!(person_id, network, clazz.attributes_from_oauth(oauth, network))
    end

    # Creates an instance of +Profile+ based on a social network API object. Returns true if successful, false
    # otherwise.
    def self.create_from_api!(person_id, network, api_attrs, type=nil)
      clazz = profile_class(network, type)
      clazz.create!(person_id, network, clazz.attributes_from_api(api_attrs, network))
    end

    # Returns the identified profile.
    def self.find(id, params = {})
      if id.is_a?(Enumerable)
        data = Profiles.fire_get(Profiles.profiles_url, params: params.merge({'id[]' => id}),
          default_data: {'profiles' => []})
        data['profiles'].map {|attrs| new_from_attributes(attrs)}
      else
        attrs = Profiles.fire_get(Profiles.profile_url(id), params: params)
        attrs ? new_from_attributes(attrs) : nil
      end
    end

    # Returns the identified profile.
    def self.find_by_email(emails, params = {})
      emails = [emails] unless emails.is_a?(Enumerable)
      data = Profiles.fire_get(Profiles.profiles_url, params: params.merge({'email[]' => emails}),
        default_data: {'profiles' => []})
      data['profiles'].map {|attrs| new_from_attributes(attrs)}
    end

    # Returns all of the profiles for the identified person.
    def self.find_all_for_person(person_id, params = {})
      data = Profiles.fire_get(Profiles.person_profiles_url(person_id), params: params,
        default_data: {'profiles' => []})
      data['profiles'].map {|attrs| new_from_attributes(attrs)}
    end

    def self.unregister_all_for_person!(person_id)
      Profiles.fire_delete(Profiles.person_registration_url(person_id), raise_on_error: true)
    end

    # Returns a single network profile for the identified person, or nil if that person does not have a profile for that
    # network. For backwards compatibility, will only return profiles with type == nil.
    def self.find_for_person_and_network(person_id, network, params = {})
      attrs = Profiles.fire_get(Profiles.person_network_profiles_url(person_id, network), params: params)
      attrs ? new_from_attributes(attrs) : nil
    end

    def self.find_for_people_and_network(person_ids, network, options = {})
      options = options.reverse_merge(default_data: {'profiles' => []})
      data = Profiles.fire_get(Profiles.network_profiles_people_url(person_ids, network), options)
      data['profiles'].map {|attrs| new_from_attributes(attrs)}
    end

    def self.find_for_uid_and_network(uid, network, params = {})
      begin
        attrs = Profiles.fire_get(Profiles.network_profiles_uid_url(network, uid), params: params)
        attrs ? new_from_attributes(attrs) : nil
      rescue Exception => e
        raise "failed to get profile for uid #{uid.inspect} and network #{network.inspect} with exception #{e.message}"
      end
    end

    def self.find_for_uids_and_network(uids, network, params = {})
      data = Profiles.fire_get(Profiles.network_profiles_url(network), params: params.merge({'uid[]' => uids}),
        default_data: {'profiles' => []})
      data['profiles'].map {|attrs| new_from_attributes(attrs)}
    end

    def self.find_for_person_or_uid_and_network(person_id, uid, network, params = {})
      profile = person_id ? self.find_for_person_and_network(person_id, network, params) : nil
      if !profile && uid
        profile = find_for_uid_and_network(uid, network, params)
        # If we found a profile by uid but not by person_id, that means we had
        # an existing unattached profile...update it to have the person_id
        profile.person_id = person_id if profile
      end
      profile
    end

    def self.delete!(person_id, network)
      Profiles.fire_delete(Profiles.person_network_profiles_url(person_id, network))
    end

    # Enqueues a job to sync the profile in the background.
    def self.async_sync(person_id, network, attrs = {})
      Rubicon::Jobs::Sync.enqueue(person_id, network, attrs)
    end

    # Enqueues a job to sync the profile attributes in the background.
    def self.async_sync_attrs(person_id, network, attrs = {})
      Rubicon::Jobs::SyncAttrs.enqueue(person_id, network, attrs)
    end

  protected
    def api_client(options = {})
      raise NotImplementedError
    end

    def api_user(options = {})
      raise NotImplementedError
    end

    # Returns the subclass of +Profile+ representing the identified social network.
    def self.profile_class(network, type=nil)
      Rubicon.const_get("#{network.capitalize}#{type.to_s.capitalize}Profile")
    end

    def self.redhook_follow_class
      Redhook::Job.const_get("Add#{self.name.split('::').last.gsub('Profile', '')}Follow")
    end

    # Returns an attributes hash constructed by examining an OAuth data hash. Expects the following keys:
    #
    # * +credentials+
    # * +network+
    def self.attributes_from_oauth(oauth, network)
      attrs = {}
      attrs['uid'] = oauth['uid']
      credentials = oauth.fetch('credentials', {})
      attrs['token'] = self.token_from_oauth(oauth)
      attrs['secret'] = self.secret_from_oauth(oauth)
      attrs['oauth_expiry'] = self.expiry_from_oauth(oauth)
      attrs['scope'] = oauth['scope'] if oauth['scope'].present?
      info = oauth.fetch('info', {})
      attrs['name'] = info['name']
      attrs['first_name'] = info['first_name']
      attrs['last_name'] = info['last_name']
      attrs['email'] = info['email']
      attrs['photo_url'] = info['image']
      attrs['profile_url'] = profile_url_from_oauth(oauth, network)
      attrs
    end

    def self.profile_url_from_oauth(oauth, network)
      oauth.fetch('info', {}).fetch('urls', {})[network.to_s.capitalize]
    end

    def self.token_from_oauth(oauth)
      data = oauth.symbolize_keys
      if data[:credentials].present?
        # XXX Rails 3.1 doesn't recursively symbolize keys, replace this
        data[:credentials]['token'] || data[:credentials][:token]
      else
        data[:token]
      end
    end

    def self.secret_from_oauth(oauth)
      data = oauth.symbolize_keys
      if data[:credentials].present?
        # XXX Rails 3.1 doesn't recursively symbolize keys, replace this
        data[:credentials]['secret'] || data[:credentials][:secret]
      else
        data[:secret]
      end
    end

    def self.expiry_from_oauth(oauth)
      # expires_at is number of seconds from now that token expires.  We want to
      # convert this to an absolute time that the credentials expire
      data = oauth.symbolize_keys
      expiry = if data[:credentials].present?
        # XXX Rails 3.1 doesn't recursively symbolize keys, replace this
        data[:credentials]['expires_at'] || data[:credentials][:expires_at]
      else
        data[:expires_at]
      end
      expiry.present?? Time.at(expiry).utc.to_datetime : nil
    end

    # Normalizes an api data hash to a rubicon attributes hash.  Must be implemented by subclasses.
    def self.attributes_from_api(api_attrs, network)
      raise NotImplementedError
    end

    def self.new_from_attributes(attrs = {})
      raise "Cannot create new profile with nil network from attrs: #{attrs.inspect[0..100]}" unless attrs['network']
      clazz = profile_class(attrs['network'], attrs['type'])
      # follows_count is a legacy attribute that we don't use anymore
      attrs = attrs.reject {|key, value| key.to_sym == :follows_count}
      attrs.delete(:token) if Rubicon.configuration.flyingdog_enabled
      clazz.new(attrs)
    end

    # Returns a persisted instance based on the provided data, or nil if the instance couldn't be persisted.
    def self.create!(person_id, network, attrs = {})
      attrs = attrs.merge(person_id: person_id, network: network.to_s)
      data = Profiles.fire_post(Profiles.profiles_url, attrs)
      data ? new(data) : nil
    end

    # @param [Hash] options  Any non-explicit options are used as attributes on the profile if created.
    # @option reassign [Boolean] If true and an existing profile is found with a different person_id, update the
    # profile to match the person_id that was passed in. Default is false.
    def self.find_or_create!(person_id, network, uid, options = {})
      profile = find_for_uid_and_network(uid, network)
      reassign = options.delete(:reassign)
      if profile
        if Rubicon.configuration.flyingdog_enabled && reassign && profile.person_id != person_id
          profile.person_id = person_id
          profile.update!
        end
      else
        clazz = profile_class(network)
        profile = clazz.create!(person_id, network, options.merge(uid: uid))
      end
      profile
    end

    protected

    def credentials_expire_after?(timestamp)
      return false unless self.oauth_expiry.present? && timestamp.present?
      timestamp = if timestamp.is_a?(Integer)
        timestamp.from_now
      elsif timestamp.is_a?(String)
        Time.zone.parse(timestamp)
      else
        timestamp.in_time_zone
      end
      self.oauth_expiry > timestamp
    end

    def scope_array(scope)
      return [] unless scope.present?
      scope.split(%r{,\s*})
    end
  end
end
