require 'ladon/model'
require 'rubicon/resource/people'

module Rubicon
  class UntargetedInvite < Ladon::Model
    attr_accessor :person_id

    def inviter_id
      person_id
    end

    def invitee_id
      nil
    end

    def targeted?
      false
    end

    # Finds the identified untargeted invite. Returns +nil+ if the service request fails.
    def self.find(id)
      data = Invites.fire_get(Invites.invite_untargeted_url(id))
      data &&= new(data)
    end

    # Finds a person's untargeted invite. Returns +nil+ if the service request fails.
    def self.find_for_person(person_id)
      data = People.fire_get(People.invite_url(person_id))
      data &&= new(data)
    end

    # Deletes a person's untargeted invite if it exists.
    def self.delete_for_person(person_id)
      People.fire_delete(People.invite_url(person_id))
    end
  end
end
