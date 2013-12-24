require 'ladon/model'
require 'rubicon/models/follow_rank'
require 'rubicon/resource/follows'

module Rubicon
  class Follow < Ladon::Model
    attr_accessor :followee, :followee_id, :follower, :follower_id, :profile_id, :rank

    def initialize(attrs = {})
      super(attrs.reject {|key, value| [:rank].include?(key.to_sym)})
      @rank = FollowRank.new_from_attributes(attrs['rank']) if attrs['rank']
    end

    def self.find_by_followee_and_follower(followee, follower)
      attrs = Follows.fire_get(Follows.profile_follower_url(followee.id, follower.id))
      attrs ? Follow.new(attrs.merge(followee: followee, followee_id: followee.id, follower: follower)) : nil
    end

    def self.find_all_by_followee(followee)
      data = Follows.fire_get(Follows.profile_follows_url(followee.id), default_data: {'follows' => []})
      data['follows'].map {|attrs| Follow.new(attrs.merge(followee: followee, followee_id: followee.id))}
    end

    def self.create(followee, follower, attrs = {})
      attrs = Follows.fire_put(Follows.profile_follower_url(followee.id, follower.id), attrs)
      follow = attrs ? Follow.new(attrs.merge(followee: followee, followee_id: followee.id, follower: follower)) : nil
      add_redhook_follow(followee, follower) if follow
      follow
    end

    def self.destroy(followee, follower)
      Follows.fire_delete(Follows.profile_follower_url(followee.id, follower.id))
    end

  protected
    def self.add_redhook_follow(followee, follower)
      followee.class.redhook_follow_class.enqueue(follower.person_id, followee.person_id)
    end
  end
end
