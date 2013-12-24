require 'spec_helper'
require 'rubicon/models/follow'
require 'rubicon/resource/follows'

describe Rubicon::Follow do
  let(:followee) { Rubicon::Profile.new('_id' => 'cafebebe') }
  let(:follower) {  Rubicon::Profile.new('_id' => 'deadbeef') }

  describe "#initialize" do
    it "initializes the rank" do
      value = 5.0
      follow = Rubicon::Follow.new('rank' => {'_type' => 'FacebookFollowRank', 'value' => value})
      follow.rank.should be_a(Rubicon::FollowRank)
      follow.rank.value.should == value
    end
  end

  describe "#find_by_followee_and_follower" do
    let(:url) { Rubicon::Follows.profile_follower_url(followee.id, follower.id) }

    it "returns the follow" do
      Rubicon::Follows.expects(:fire_get).with(url).returns({'follower_id' => follower.id})
      follow = Rubicon::Follow.find_by_followee_and_follower(followee, follower)
      follow.should be_a(Rubicon::Follow)
      follow.follower.should == follower
      follow.followee.should == followee
      follow.followee_id.should == followee.id
    end

    it "returns nil when the server responds with an error" do
      Rubicon::Follows.expects(:fire_get).with(url).returns(nil)
      Rubicon::Follow.find_by_followee_and_follower(followee, follower).should be_nil
    end
  end

  describe "#find_all_by_followee" do
    let(:url) { Rubicon::Follows.profile_follows_url(followee.id) }
    let(:default_data) { {'follows' => []} }

    it "returns the follows" do
      Rubicon::Follows.expects(:fire_get).with(url, default_data: default_data).
        returns('follows' => [{'follower_id' => follower.id}])
      follows = Rubicon::Follow.find_all_by_followee(followee)
      follows.should have(1).follow
      follows.first.should be_a(Rubicon::Follow)
      follows.first.followee.should == followee
      follows.first.followee_id.should == followee.id
    end

    it "returns an empty array when the server responds with an error" do
      Rubicon::Follows.expects(:fire_get).with(url, default_data: default_data).returns(default_data)
      follows = Rubicon::Follow.find_all_by_followee(followee)
      follows.should have(0).follows
    end
  end

  describe "#create" do
    let(:url) { Rubicon::Follows.profile_follower_url(followee.id, follower.id) }

    it "creates and returns the follow" do
      Rubicon::Follow.expects(:add_redhook_follow).with(followee, follower)
      Rubicon::Follows.expects(:fire_put).with(url, is_a(Hash)).returns({'follower_id' => follower.id})
      follow = Rubicon::Follow.create(followee, follower)
      follow.should be_a(Rubicon::Follow)
      follow.follower.should == follower
      follow.followee.should == followee
      follow.followee_id.should == followee.id
    end

    it "returns nil when the server responds with an error" do
      Rubicon::Follow.expects(:add_redhook_follow).never
      Rubicon::Follows.expects(:fire_put).with(url, is_a(Hash)).returns(nil)
      Rubicon::Follow.create(followee, follower).should be_nil
    end
  end

  describe "#destroy" do
    let(:url) { Rubicon::Follows.profile_follower_url(followee.id, follower.id) }

    it "destroys the follow" do
      Rubicon::Follows.expects(:fire_delete).with(url)
      Rubicon::Follow.destroy(followee, follower)
    end
  end
end
