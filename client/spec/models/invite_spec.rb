require 'spec_helper'
require 'rubicon/models/invite'

describe Rubicon::Invite do
  it "validates invitee_id is present" do
    invite = Rubicon::Invite.new
    invite.should_not be_valid
    invite.errors[:invitee_id].first.should =~ %r{can\'t be blank}
  end

  it "validates inviter_id is present" do
    invite = Rubicon::Invite.new
    invite.should_not be_valid
    invite.errors[:inviter_id].first.should =~ %r{can\'t be blank}
  end

  it "creates a valid invite" do
    invitee_id = 'deadbeef'
    inviter_id = 'cafebebe'
    entity = {'inviter_id' => inviter_id, 'invitee_id' => invitee_id, '_id' => 'deadbeef'}
    Rubicon::Invites.expects(:fire_put).
      with(Rubicon::Invites.invites_from_url(invitee_id, inviter_id), is_a(Hash)).returns(entity)
    invite = Rubicon::Invite.create(invitee_id, inviter_id)
    invite.should be_a(Rubicon::Invite)
  end

  it "does not create an invalid invite" do
    Rubicon::Invites.expects(:fire_put).never
    invite = Rubicon::Invite.create(nil, nil, {})
    invite.should be_a(Rubicon::Invite)
    invite.should_not be_valid
  end

  it "handles service failure when creating an invite" do
    invitee_id = 'deadbeef'
    inviter_id = 'cafebebe'
    Rubicon::Invites.expects(:fire_put).returns(nil)
    invite = Rubicon::Invite.create(invitee_id, inviter_id)
    invite.should be_nil
  end

  it "deletes all invites" do
    invitee_id = 'deadbeef'
    Rubicon::Invites.expects(:fire_delete).with(Rubicon::Invites.invites_url(invitee_id))
    Rubicon::Invite.delete_all(invitee_id)
  end

  it "deletes a single invite" do
    invitee_id = 'deadbeef'
    inviter_id = 'feedbaca'
    Rubicon::Invites.expects(:fire_delete).with(Rubicon::Invites.invites_from_url(invitee_id, inviter_id))
    Rubicon::Invite.delete_from(invitee_id, inviter_id)
  end

  describe "invites? tests" do
    let(:inviter) { Rubicon::Profile.new('_id' => 'phatpipe') }
    let(:invitee) { Rubicon::Profile.new('_id' => 'deadbeef') }

    it "returns true when inviter exists" do
      Rubicon::Profiles.expects(:fire_get).returns({'_id' => 'phatpipe', 'network' => 'twitter'})
      Rubicon::Invite.invites?(inviter, invitee).should be_true
    end

    it "returns false when inviter doesn't exist" do
      Rubicon::Profiles.expects(:fire_get).returns(false)
      Rubicon::Invite.invites?(inviter, invitee).should be_false
    end

    it "returns value with profile as input" do
      Rubicon::Profiles.expects(:fire_get).returns({'_id' => 'phatpipe', 'network' => 'twitter'})
      Rubicon::Invite.invites?(inviter, invitee).should be_true
    end

    it "returns value with id as input" do
      Rubicon::Profiles.expects(:fire_get).returns({'_id' => 'phatpipe', 'network' => 'twitter'})
      Rubicon::Invite.invites?(inviter, invitee.id).should be_true
    end
  end

  describe "inviters tests" do
    let(:inviter) { Rubicon::Profile.new('_id' => 'phatpipe') }
    let(:invitee) { Rubicon::Profile.new('_id' => 'deadbeef') }

    it "returns the list of inviter profiles" do
      Rubicon::Profiles.expects(:fire_get).returns('profiles' => [{'_id' => 'phatpipe', 'network' => 'twitter'}])
      Rubicon::Invite.inviters(invitee.id).should be_a(Array)
    end
  end

  describe "#find" do
    it "gets an invite" do
      id = 'phatpipe'
      Rubicon::Invites.expects(:fire_get).with(Rubicon::Invites.invite_url(id)).
        returns({'_id' => id, 'inviter_id' => 'deadbeef', 'invitee_id' => 'cafebebe'})
      Rubicon::Invite.find(id).should be_a(Rubicon::Invite)
    end
  end
end
