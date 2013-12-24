require 'mongoid'

class UntargetedInvite
  include Mongoid::Document
  include Mongoid::Timestamps

  index :created_at
  index :updated_at

  field :person_id, type: Integer
  index :person_id
  validates_uniqueness_of :person_id
end
