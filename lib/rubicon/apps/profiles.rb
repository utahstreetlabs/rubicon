require 'dino/base'
require 'dino/mongoid'
require 'rubicon/models'

module Rubicon
  class ProfilesApp < Dino::Base
    include Dino::MongoidApp

    DEFAULT_FOLLOW_FIELDS = [:person_id, :network, :uid, :name]

    get '/people/:id/profiles' do
      do_get do
        options = options_from_params(params)
        logger.debug("Finding all profiles for person #{params[:id]} with options #{options.inspect}")
        profiles_collection(Profile.for_person(params[:id]), options)
      end
    end

    # deleting profiles from rubicon is most often not what we want
    # because the profile and its associated uid quite likely exist
    # in the graphs of other registered users, so this endpoint is
    # to just remove the parts of the profile that make it look like
    # it belongs to a registered user
    delete '/people/:id/registration' do
      do_delete do
        # load as array so we're not mutating the objects in a live cursor
        Profile.where(person_id: params[:id].to_i).to_a.each do |profile|
          profile.unregister!
        end
        nil
      end
    end

    get '/people/:id/profiles/:network' do
      do_get do
        options = options_from_params(params, exclude: :network)
        logger.debug("Finding #{params[:network]} profile for person #{params[:id]} with options #{options.inspect}")
        options.merge!({secure: options[:secure]}) if options[:secure]
        profile = Profile.find_existing_profile(params[:id], params[:network], options)
        raise Dino::NotFound unless profile
        profile_object(profile, options)
      end
    end

    delete '/people/:id/profiles/:network' do
      do_delete do
        logger.debug("Deleting profile for person id #{params[:id]} and network #{params[:network]}")
        Profile.destroy_all(person_id: params[:id], network: params[:network])
      end
    end

    get '/networks/:network/profiles/count' do
      do_get do
        type = params[:type].present?? params[:type] : nil
        if type
          logger.debug("Counting #{params[:network]} profiles of type #{type}}")
        else
          logger.debug("Counting untyped #{params[:network]} profiles")
        end
        {count: Profile.count(conditions: {network: params[:network], type: type})}
      end
    end

    get '/networks/:network/profiles/people/:person_ids' do
      do_get do
        options = options_from_params(params, exclude: :network)
        person_ids = params[:person_ids].split(';')
        logger.debug("Finding #{params[:network]} profiles for person_ids #{person_ids} with options #{options.inspect}")
        profiles_collection(Profile.find_existing_profiles_by_person(person_ids, params[:network]), options)
      end
    end

    get '/networks/:network/profiles/:id' do
      do_get do
        options = options_from_params(params, exclude: :network)
        logger.debug("Finding #{params[:network]} profile for uid #{params[:id]} with options #{options.inspect}")
        profile = Profile.find_existing_profile_by_uid(params[:id], params[:network])
        raise Dino::NotFound unless profile
        profile_object(profile, options)
      end
    end

    get '/networks/:network/profiles' do
      do_get do
        uids = params.fetch('uid', [])
        options = options_from_params(params, exclude: [:uid, :network])
        raise Dino::BadRequest.new("uids must be specified like uid[]=4&uid[]=5") unless uids.is_a? Array
        logger.debug("Finding #{params[:network]} profile for uids #{uids} with options #{options.inspect}")
        profiles_collection(Profile.find_existing_profiles(uids, params[:network]))
      end
    end

    delete '/networks/:network/profiles' do
      do_delete do
        type = params[:type].present?? params[:type] : nil
        if type
          logger.debug("Deleting #{params[:network]} profiles of type #{type}}")
        else
          logger.debug("Deleting untyped #{params[:network]} profiles")
        end
        Profile.destroy_all(network: params[:network], type: type)
      end
    end

    get '/profiles' do
      do_get do
        ids = params.fetch('id', [])
        emails = params.fetch('email', [])
        options = options_from_params(params, exclude: [:network, :email])
        unless ids.is_a?(Array) or emails.any?
          raise Dino::BadRequest.new("emails or ids must be specified like email[]=ham@eggs.com or id[]=4e680eec50a79914b200006")
        end
        logger.debug("Finding profiles for ids #{ids} or emails #{emails} with options #{options.inspect}")
        profiles_collection(Profile.any_of({:_id.in => ids}, {:email.in => emails}), options)
      end
    end

    post '/profiles' do
      do_post do |entity|
        raise Dino::BadRequest.new("Entity required") unless entity
        raise Dino::BadRequest.new("Network required") unless entity['network']
        logger.debug("Creating profile with attributes #{entity.inspect}")
        clazz = Profile.profile_class(entity['network'])
        profile_object(clazz.create!(entity))
      end
    end

    get '/profiles/count' do
      do_get do
        logger.debug("Counting all profiles")
        {count: Profile.count}
      end
    end

    get '/profiles/:id' do
      do_get do
        options = options_from_params(params)
        logger.debug("Getting profile #{params[:id]} with options #{options.inspect}")
        profile_object(Profile.find(params[:id]), options)
      end
    end

    put '/profiles/:id' do
      do_put do |entity|
        profile = Profile.find(params[:id])
        raise Dino::BadRequest.new("Entity required") unless entity
        raise Dino::NotFound unless profile
        logger.debug("Updating profile #{params[:id]}")
        profile.update_attributes!(entity)
        profile_object(profile)
      end
    end

    delete '/profiles/:id' do
      do_delete do
        logger.debug("Deleting profile #{params[:id]}")
        Profile.destroy_all(_id: params[:id])
      end
    end

    # unregister a single profile
    delete '/profiles/:id/registration' do
      do_delete do
        logger.debug("Unregistering profile #{params[:id]}")
        profile = Profile.find(params[:id])
        profile.unregister! if profile
      end
    end

    get '/profiles/:id/followers' do
      do_get do
        logger.debug("Finding all profiles following profile #{params[:id]}")
        options = follow_options_from_params(params)
        profile = Profile.find(params[:id])
        profiles_collection(profile.followers(options), options)
      end
    end

    # Return the set of profiles that this profile is following
    get '/profiles/:id/following' do
      do_get do
        logger.debug("Finding all profiles followed by profile #{params[:id]}")
        options = follow_options_from_params(params)
        profile = Profile.find(params[:id])
        profiles_collection(profile.following, options)
      end
    end

    # Return the set of profiles that this profile is inviting
    get '/profiles/:id/inviting' do
      do_get do
        options = options_from_params(params)
        logger.debug("Finding all profiles invited by profile #{params[:id]}")
        profile = Profile.find(params[:id])
        profiles_collection(profile.inviting, options)
      end
    end

    get '/profiles/:id/followers/uninvited' do
      do_get do
        options = options_from_params(params, exclude: [:random, :fields, :offset, :name])
        logger.debug("Finding uninvited follower profiles for profile #{params[:id]}")
        profile = Profile.find(params[:id])
        profiles_collection(profile.uninvited_followers(params), options)
      end
    end

    get '/profiles/:id/inviters/following/:followee_id' do
      do_get do
        logger.debug("Finding all inviters for profile #{params[:id]} also following #{params[:followee_id]}")
        profile = Profile.find(params[:id])
        {profiles: profile.inviters_following(params[:followee_id]).map {|p| p.serializable_hash}}
      end
    end

    get '/profiles/:id/follows' do
      # XXX: pretty sure this method isn't used, as it's just a bad version of /profiles/:id/followers
      # leaving for now until i can confirm
      do_get do
        logger.debug("Finding all follows for profile #{params[:id]}")
        profile = Profile.find(params[:id])
        {follows: profile.follows.to_a}
      end
    end

    get '/profiles/:id/follows/:follower_id' do
      do_get do
        profile = Profile.find(params[:id])
        logger.debug("Finding follow #{params[:follower_id]} for profile #{params[:id]}")
        follow = profile.follows.where(follower_id: params[:follower_id]).first
        raise Dino::NotFound unless follow
        follow
      end
    end

    put '/profiles/:id/follows/:follower_id' do
      do_put do |entity|
        profile = Profile.find(params[:id])
        raise Dino::BadRequest.new("Entity required") unless entity
        raise Dino::NotFound unless profile
        logger.debug("Adding follow between profile #{params[:id]} and follower #{params[:follower_id]}")
        profile.followed!(BSON::ObjectId.from_string(params[:follower_id]), entity['rank'])
      end
    end

    delete '/profiles/:id/follows/:follower_id' do
      do_delete do
        profile = Profile.find(params[:id])
        logger.debug("Deleting follow between profile #{params[:id]} and follower #{params[:follower_id]}")
        profile.unfollowed!(BSON::ObjectId.from_string(params[:follower_id]))
      end
    end

    get '/follows/count' do
      do_get do
        logger.debug("Counting all follows")
        {count: Follow.count}
      end
    end

  protected
    # Convert params hash from request to appropriate options for model method.
    # +:id+ is excluded by default
    # @option options [Array] :exclude List of keys to be removed from returned hash
    def options_from_params(params, options = {})
      excludes = Array.wrap(options[:exclude])
      excludes << :id
      params.symbolize_keys.except(*excludes)
    end

    # Common conversions for follower / following requests
    def follow_options_from_params(params)
      options = options_from_params(params)
      uids = Array.wrap(options.delete(:uid))
      fields = options.delete(:field) || DEFAULT_FOLLOW_FIELDS
      options.merge(uids: uids, fields: fields)
    end

    def profiles_collection(profiles, options = {})
      profiles ||= []
      # need to use a +map+ instead of +each+ here because +profiles+ is initially a mongo cursor
      # and while +#connection_count!+ is a mutating method, the next call to +profiles.map+ would reload from the
      # cursor.
      # this way we instantiate the smallest possible number of arrays.
      profiles = profiles.map {|p| p.connection_count!; p} if options[:connection_count]
      {profiles: profiles.map {|p| p.serializable_hash(options[:fields])}}
    end

    def profile_object(profile, options = {})
      profile.connection_count!(options) if options[:connection_count]
      profile.serializable_hash
    end
  end
end
