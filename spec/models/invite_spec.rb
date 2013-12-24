require 'spec_helper'
require 'rubicon/models/profile'
require 'rubicon/models/invite'

describe Invite do
  it "creates an invite for a profile" do
    # Create the inviteee profile
    profile = FactoryGirl.create(:profile)

    # Create the inviter profile
    profile_inviter = FactoryGirl.create(:profile)

    # Hook them up
    profile.invites.create(inviter_id: profile_inviter.id)
    profile.reload
    profile.invites.count.should == 1
  end

  it "removes an invite for a profile" do
    # Create the invitee profile
    profile = FactoryGirl.create(:profile)
    profile.invites.count.should == 0

    # Create the inviter profile
    profile_inviter = FactoryGirl.create(:profile)
    profile_inviter.invites.count.should == 0

    # Hook them up
    profile.invites.create!(inviter_id: profile_inviter.id)
    profile.reload
    profile.invites.count.should == 1

    profile.invites.destroy_all
    profile.invites.count.should == 0
  end
end
