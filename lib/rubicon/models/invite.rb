require 'mongoid'
require 'rubicon/models/profile'

class Invite
  include Mongoid::Document
  include Mongoid::Timestamps

  index :created_at
  index :updated_at

  # inviter_id is the id of the inviter profile
  field :inviter_id, type: Integer
  index :inviter_id
  validates_presence_of :inviter_id
  validates_uniqueness_of :inviter_id

  embedded_in :profile

  # @param [BSON::ObjectId] invite_id the object id of the invite to find
  def self.find_invite(invite_id)
    profile = Profile.where('invites._id' => invite_id).first
    profile ? profile.invites.detect {|i| i.id == invite_id } : nil
  end

  # Transforms a listing into a hash that suitably represents the listing on the wire. It excludes all associated
  # documents that are hidden or have their own endpoints and converts the BSON id into its string form.
  def to_wire_hash
    hash = serializable_hash
    hash['_id'] = hash['_id'].to_s
    hash['inviter_id'] = hash['inviter_id'].to_s
    hash['invitee_id'] = self.profile.id.to_s
    hash
  end
end
