require 'dino/model'
require 'mongoid'
require 'rubicon/models/follow'
require 'rubicon/models/invite'

class Profile
  include Mongoid::Document
  include Mongoid::Timestamps
  include Dino::Model

  # a synthetic attribute that gets filled in when the caller calls +#connection_count!+
  attr_reader :connection_count

  index :created_at
  index :updated_at

  field :person_id, type: Integer, default: nil
  index :person_id

  field :network, type: String
  validates_presence_of :network
  index :network

  field :api_follows_count, type: Integer, default: 0
  index :api_follows_count

  # type specifier to distinguish different profiles in the same
  # network, ie, pages, blogs, groups, etc
  field :type, type: String
  index :type

  # Distinguish profiles authenticated via different methods, secure
  # vs. insecure.
  field :secure, type: Boolean, default: false
  index :secure

  # Stores an array of oauth permissions granted to this profile.
  field :scope, type: String, default: nil
  index :scope

  index [[:person_id, Mongo::ASCENDING], [:network, Mongo::ASCENDING]]
  validates_uniqueness_of :uid, scope: [:network]
  validates_uniqueness_of :network, scope: [:person_id, :type], if: Proc.new {|p| p.type == nil}
  validates_uniqueness_of :secure, scope: [:person_id, :network, :type], if: Proc.new {|p| p.type == nil}

  # the network's unique identifier for the profile - can't assume it's a number like FacebookProfile does
  field :uid, type: String
  validates_presence_of :uid
  index :uid

  # User's short name or user name on the network
  field :username, type: String
  index :username

  # OAuth and OAuth 2.0 access token allowing access from Copious to the network profile
  field :token, type: String

  # OAuth access token secret (ie password)
  field :secret, type: String

  # OAuth expiration time, if known.
  field :oauth_expiry, type: DateTime, default: Time.now.utc
  index :oauth_expiry

  # attributes copied from the network's version of the profile
  field :name, type: String
  field :first_name, type: String
  field :last_name, type: String
  field :email, type: String
  field :profile_url, type: String
  field :photo_url, type: String
  field :gender, type: String
  field :location, type: String
  field :birthday, type: Date

  field :synced_at, type: DateTime, default: nil
  index :synced_at

  has_many :follows, :validate => false, :autosave => true
  embeds_many :invites, :validate => false

  def self.find_existing_profile(person_id, network, options)
    conditions = {person_id: person_id, network: network}
    conditions.merge!(secure: options[:secure]) if options[:secure]
    first(conditions: conditions)
  end

  def self.find_existing_profile_by_uid(uid, network)
    first(conditions: {uid: uid, network: network})
  end

  def self.find_existing_profiles_by_person(person_ids, network)
    any_in(person_id: person_ids).and(network: network)
  end

  def self.find_existing_profiles(uids, network)
    any_in(uid: uids).and(network: network)
  end

  def self.for_person(person_id)
    all(conditions: {"person_id" => person_id.to_i})
  end

  def self.profile_class(network)
    Profile
  end

  def destroy_follows
    # Remove follows from other profiles to this one
    follows.destroy_all
    # Remove follows from this profile to another
    Follow.where(follower_id: self._id).destroy_all
  end
  protected :destroy_follows
  after_destroy :destroy_follows

  def follow(follower_id)
    follows.where(follower_id: follower_id).first
  end

  # Creates or updates a follow between another profile and this one.
  #
  # @param [BSON::ObjectId] follower_id the object id of the following profile
  # @param [Hash] rank (nil) the follow rank data for the following profile; causes the follow's rank to be created or
  #   updated when provided
  # @return [Follow] the created or updated follow
  def followed!(follower_id, rank = nil)
    follow = follows.find_or_create_by(follower_id: follower_id, profile_id: self.id)
    if rank
      if follow.rank
        follow.rank.update_attributes(rank)
      else
        follow.rank = FollowRank.new_for_network(self.network, rank)
        follow.save!
      end
    end
    follow
  end

  # Removes the follow between another profile and this one.
  #
  # @param [BSON::ObjectId] follower_id the object id of the following profile
  def unfollowed!(follower_id)
    follows.where(follower_id: follower_id).destroy_all
  end

  # Creates or updates a targeted invite from another profile.
  #
  # @param [BSON::ObjectId] inviter_id the object id of the inviting profile
  # @return [Invite] the created or updated invite
  def invited!(inviter_id)
    invites.find_or_create_by(inviter_id: inviter_id)
  end

  # Removes the targeted invite from another profile.
  #
  # @param [BSON::ObjectId] inviter_id the object id of the inviting profile
  def uninvited!(inviter_id)
    invites.where(inviter_id: inviter_id).destroy_all
  end

  # Returns true if the profile has access token, false otherwise.
  def connected?
    token.present?
  end

  # compute the +connection_count+ attribute. forcing this to be done on demand keeps us from having to suffer the
  # performance hit of counting the association whenever the object is serialized.
  def connection_count!(options = {})
    if options[:onboarded_only]
      # onboarded profiles will have been synced by mendocino.
      @connection_count = self.class.any_in(_id: Follow.where(profile_id: self.id).map(&:follower_id)).
        where(:synced_at.exists => true).count
    else
      @connection_count = (api_follows_count && api_follows_count > 0) ? api_follows_count : follows.count
    end
  end

  # this is a read-only attribute, but the empty mutator allows Active Model attribute setting methods to work
  # without raising +NoMethodError - undefined method `connection_count='+
  def connection_count=(value)
  end

  # Returns profiles we are following.
  def following
    self.class.any_in(_id: Follow.where(follower_id: self.id).map(&:profile_id)).to_a
  end

  # Returns profiles we are inviting.
  def inviting
    self.class.where(:'invites.inviter_id' => self.id).to_a
  end

  # Returns follower profiles.
  # @option options [Array] :uids follower profile uids to return; if not a follower, not returned
  # @option options [Integer] :limit maximum # of followers to return
  # @option options [Bool] :rank whether or not to order by friend rank (default false)
  # @option options [Array] :fields Fields to be loaded from mongo
  # @option options [Bool] :onboarded_only whether or not to only return onboarded profiles
  def followers(options = {})
    uids = Array.wrap(options.fetch(:uids, [])).compact
    limit = options[:limit].to_i

    scope = follows.only(:follower_id)
    scope = scope.any_in(follower_id: uids.map {|u| BSON::ObjectId.from_string(u)}) if uids.any?
    scope = scope.order_by([['fr', Mongo::DESCENDING]]) if options[:rank]
    # If we're only returning onboarded users, we unfortunately need to grab all followers
    # in order to then examine the associated profiles' synced_at fields.  If not, we can
    # limit here, which lets us query for fewer profiles.
    scope = scope.limit(limit) if (limit && !options[:onboarded_only])

    profiles = self.class.any_in(_id: scope.map { |p| p.follower_id })
    if options[:onboarded_only]
      profiles = profiles.where(:synced_at.exists => true)
      profiles = profiles.limit(limit) if limit
    end
    profiles = profiles.only(*options[:fields]) if options[:fields]
    profiles
  end

  # Returns unconnected follower profiles that do not have an invite from this profile. Profiles are ordered by follow
  # rank, descending.
  #
  # @option options [String] :name If present, a case insensitive substring match is performed against profile names
  # @option options [Array[String, Symbol]] :fields (all fields) The list of field names to be included in the result
  #   profiles
  # @option options [Integer] (10) :limit The maximum number of profiles to return
  # @option options [Integer] (0) :offset If specified, skips the first number of results
  def uninvited_followers(options = {})
    limit = options[:limit].to_i
    limit = 10 unless limit > 0
    offset = options[:offset].to_i
    offset = 0 if offset < 0

    # results to ensure unique profile ids
    # uids to ensure unique uids returned
    results = {}
    uids = Set.new
    current_offset = 0
    while results.count < (offset + limit)
      f = follows.only(:follower_id).order_by([['fr', Mongo::DESCENDING]]).skip(current_offset).limit(limit).
        map(&:follower_id)
      break unless f.count > 0

      scope = self.class.any_in(_id: f) # followers
      scope = scope.where(:'invites.inviter_id'.ne => self.id) # uninvited
      scope = scope.where(name: /#{options[:name]}/i) if options[:name].present? # matching the name filter
      scope = scope.only(*options[:fields]) if options[:fields] # including only desired fields
      # order profiles based on follows order and elmintate duplicates based on profile id and uid
      f.each {|id| results[id] ||= nil}
      scope.each {|p| results[p._id] = p if uids.add?(p.uid)}
      results.reject! {|id,p| !p}
      current_offset += f.count
    end
    results.values.slice(offset, limit)
  end

  def inviters_following(followee_id)
    return [] unless invites.any?
    inviters = self.class.any_in(_id: invites.map(&:inviter_id)).to_a
    inviters_following_ids = Follow.where(:'follower_id'.in => inviters.map(&:id), :'profile_id' => followee_id).
      map(&:follower_id)
    inviters.select {|p| inviters_following_ids.include?(p.id)}
  end

  UNREGISTERED_KEYS = ['_id', 'person_id', 'network', '_type', 'uid', 'name', 'created_at', 'updated_at']
  def unregister!
    attributes.except(*UNREGISTERED_KEYS).each { |k,v| write_attribute(k, nil) }
    save!
  end

  def serializable_hash(fields = nil)
    h = if fields
      super(only: fields)
    else
      # follows_count is a legacy field we can drop someday
      h = super(except: [:follows_count, :created_at, :updated_at])
      h['_type'] = _type
      h['connection_count'] = connection_count
      h
    end
    h['_id'] = id.to_s
    h
  end
end
