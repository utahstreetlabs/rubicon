require 'spec_helper'
require 'rubicon/models/follow'
require 'rubicon/models/follow_rank'

describe FacebookFollowRank do
  it "creates a Facebook follow rank for a follow" do
    attrs = {
      value: 1,
      shared_connections_attributes: {
        value: 25, coefficient: 0.35
      },
      network_affinity_attributes: {
        value: 49.75, coefficient: 0.36, photo_tags_attributes: {value: 12.777, coefficient: 0.38}
      }
    }
    follow = FactoryGirl.create(:follow)
    follow.rank = FacebookFollowRank.new(attrs)
    follow.save.should be_true
    follow.rank.should be
    follow.rank.value.should == attrs[:value]
    follow.rank.shared_connections.value.should == attrs[:shared_connections_attributes][:value]
    follow.rank.shared_connections.coefficient.should == attrs[:shared_connections_attributes][:coefficient]
    follow.rank.network_affinity.value.should == attrs[:network_affinity_attributes][:value]
    follow.rank.network_affinity.coefficient.should == attrs[:network_affinity_attributes][:coefficient]
    follow.rank.network_affinity.photo_tags.value.should ==
      attrs[:network_affinity_attributes][:photo_tags_attributes][:value]
    follow.rank.network_affinity.photo_tags.coefficient.should ==
      attrs[:network_affinity_attributes][:photo_tags_attributes][:coefficient]
  end
end
