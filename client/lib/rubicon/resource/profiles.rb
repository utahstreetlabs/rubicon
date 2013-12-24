require 'rubicon/resource/base'

module Rubicon
  class Profiles < Resource::Base
    def self.person_profiles_url(person_id)
      "/people/#{person_id}/profiles"
    end

    def self.person_registration_url(person_id)
      "/people/#{person_id}/registration"
    end

    def self.person_network_profiles_url(person_id, network)
      "/people/#{person_id}/profiles/#{network}"
    end

    def self.network_profiles_uid_url(network, uid)
      "/networks/#{network}/profiles/#{uid}"
    end

    def self.network_profiles_url(network)
      "/networks/#{network}/profiles"
    end

    def self.network_profiles_people_url(person_ids, network)
      absolute_url("/networks/#{network}/profiles/people/#{grouped_query_path_segment(person_ids)}")
    end

    def self.profiles_url
      "/profiles"
    end

    def self.profile_followers_url(profile_id, options = {})
      params = {}
      params['uid[]'] = options[:uids] if options[:uids]
      absolute_url("/profiles/#{profile_id}/followers", params: params)
    end

    def self.profile_followers_uninvited_url(profile_id)
      "/profiles/#{profile_id}/followers/uninvited"
    end

    def self.profile_inviters_following_url(profile_id, followee_id)
      "/profiles/#{profile_id}/inviters/following/#{followee_id}"
    end

    def self.profile_following_url(profile_id)
      "/profiles/#{profile_id}/following"
    end

    def self.profile_inviting_url(profile_id)
      "/profiles/#{profile_id}/inviting"
    end

    def self.profile_url(id)
      "/profiles/#{id}"
    end

    def self.profile_registration_url(id)
      "/profiles/#{id}/registration"
    end

    def self.grouped_query_path_segment(ids)
      ids.sort.join(';')
    end
  end
end
