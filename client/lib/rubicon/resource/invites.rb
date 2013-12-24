require 'rubicon/resource/base'

module Rubicon
  class Invites < Resource::Base
    def self.invites_url(profile_id)
      "/profiles/#{profile_id}/invites"
    end

    def self.inviters_url(profile_id)
      "/profiles/#{profile_id}/inviters"
    end

    def self.invites_from_url(profile_id, inviter_id)
      "/profiles/#{profile_id}/invites/from/#{inviter_id}"
    end

    def self.invite_url(invite_id)
      "/invites/#{invite_id}"
    end

    def self.invite_untargeted_url(invite_id)
      "/invites/untargeted/#{invite_id}"
    end
  end
end
