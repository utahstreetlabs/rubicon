require 'spec_helper'
require 'rubicon/models/profile'
require 'rubicon/models/follow'

describe Follow do
  it "creates a follow for a person" do
    # Create the followee profile
    profile = FactoryGirl.create(:profile)
    profile.follows.count.should == 0

    # Create the follower profile
    profile_follower = FactoryGirl.create(:profile)
    profile_follower.follows.count.should == 0

    # Hook them up
    profile.follows.create(follower_id: profile_follower.id)
    profile.reload
    profile.follows.count.should == 1
  end

  it "removes a follow for a person" do
    # Create the followee profile
    profile = FactoryGirl.create(:profile)
    profile.follows.count.should == 0

    # Create the follower profile
    profile_follower = FactoryGirl.create(:profile)
    profile_follower.follows.count.should == 0

    # Hook them up
    profile.follows.create!(follower_id: profile_follower.id)
    profile.reload
    profile.follows.count.should == 1

    # Destroy the follower profile
    profile_follower.destroy

    profile.reload
    profile.follows.count.should == 0
  end
end
