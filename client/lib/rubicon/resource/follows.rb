require 'rubicon/resource/base'

module Rubicon
  class Follows < Resource::Base
    def self.profile_follower_url(profile_id, follower_id)
      "/profiles/#{profile_id}/follows/#{follower_id}"
    end

    def self.profile_follows_url(profile_id)
      "/profiles/#{profile_id}/follows"
    end
  end
end
