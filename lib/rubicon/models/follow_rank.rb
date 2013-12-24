require 'mongoid'

class FollowRank
  include Mongoid::Document
  include Mongoid::Timestamps

  index :created_at
  index :updated_at

  field :value, type: Float
  index :value
  validates_presence_of :value

  embedded_in :profile

  embeds_one :shared_connections, class_name: 'FollowRankMetadata'
  accepts_nested_attributes_for :shared_connections

  def self.new_for_network(network, attrs = {})
    case network.to_sym
    when :facebook then FacebookFollowRank.new(attrs)
    else raise "FollowRank not implemented for #{network}"
    end
  end

  def serializable_hash(options = nil)
    options ||= {}
    options.merge!(except: [:created_at, :updated_at])
    h = super(options)
    h['_id'] = id.to_s
    h['_type'] = _type
    h
  end
end

class FollowRankMetadata
  include Mongoid::Document

  field :value, type: Float
  validates_presence_of :value

  field :coefficient, type: Float
  validates_presence_of :coefficient
end

require 'rubicon/models/facebook_follow_rank'
