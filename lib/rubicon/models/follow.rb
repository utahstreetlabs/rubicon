require 'mongoid'
require 'rubicon/models/follow_rank'
require 'rubicon/models/profile'

class Follow
  include Mongoid::Document
  include Mongoid::Timestamps

  index :created_at
  index :updated_at

  # follower_id is the id of the follower profile
  field :follower_id, type: Integer
  index :follower_id
  validates_presence_of :follower_id

  belongs_to :profile, :inverse_of => :follows
  index :profile_id

  embeds_one :rank, class_name: 'FollowRank'
  accepts_nested_attributes_for :rank
end
