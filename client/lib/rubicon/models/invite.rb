require 'ladon/model'
require 'rubicon/resource/invites'

module Rubicon
  class Invite < Ladon::Model
    attr_accessor :inviter_id, :invitee_id
    validates :inviter_id, presence: true
    validates :invitee_id, presence: true

    def targeted?
      true
    end

    # Creates and returns an +Invite+ based on the provided attributes hash. Returns nil if the service request
    # fails.
    def self.create(invitee_id, inviter_id, attrs = {})
      invite = new(attrs.merge(inviter_id: inviter_id, invitee_id: invitee_id))
      if invite.valid?
        saved = Invites.fire_put(Invites.invites_from_url(invitee_id, inviter_id), {})
        rv = saved ? new(saved.merge(inviter_id: inviter_id, invitee_id: invitee_id)) : nil
      else
        invite
      end
    end

    # Removes all invites for a profile (the invitee)
    def self.delete_all(invitee_id)
      Invites.fire_delete(Invites.invites_url(invitee_id))
    end

    # Removes all invites from an inviter for a profile (the invitee)
    def self.delete_from(invitee_id, inviter_id)
      Invites.fire_delete(Invites.invites_from_url(invitee_id, inviter_id))
    end

    def self.invites?(inviter_profile_or_id, invitee_profile_or_id)
      inviter_id = inviter_profile_or_id.is_a?(Profile) ? inviter_profile_or_id.id : inviter_profile_or_id
      invitee_id = invitee_profile_or_id.is_a?(Profile) ? invitee_profile_or_id.id : invitee_profile_or_id
      !!Profiles.fire_get(Invites.invites_from_url(invitee_id, inviter_id))
    end

    def self.inviters(invitee_profile_or_id)
      invitee_id = invitee_profile_or_id.is_a?(Profile) ? invitee_profile_or_id.id : invitee_profile_or_id
      data = Profiles.fire_get(Invites.inviters_url(invitee_id), default_data: {'profiles' => []})
      data['profiles'].map {|attrs| Profile.new_from_attributes(attrs)}
    end

    # Returns the identified invite.
    def self.find(id)
      attrs = Invites.fire_get(Invites.invite_url(id))
      attrs ? Invite.new(attrs) : nil
    end
  end
end
