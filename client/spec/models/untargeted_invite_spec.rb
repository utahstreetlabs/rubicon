require 'spec_helper'
require 'rubicon/models/untargeted_invite'

describe Rubicon::UntargetedInvite do
  let(:id) { 'deadbeef' }
  let(:person_id) { 5555 }
  let(:attrs) { {'_id' => id, 'person_id' => person_id} }
  let(:invite_url) { Rubicon::Invites.invite_untargeted_url(id) }
  let(:person_invite_url) { Rubicon::People.invite_url(person_id) }

  it 'finds an identified invite' do
    Rubicon::Invites.expects(:fire_get).with(invite_url).returns(attrs)
    invite = Rubicon::UntargetedInvite.find(id)
    invite.should be_a(Rubicon::UntargetedInvite)
    invite.person_id.should == person_id
  end

  it "finds a person's invite" do
    Rubicon::People.expects(:fire_get).with(person_invite_url).returns(attrs)
    invite = Rubicon::UntargetedInvite.find_for_person(person_id)
    invite.should be_a(Rubicon::UntargetedInvite)
    invite.person_id.should == person_id
  end

  it "returns nil when finding a person's invite causes a server error" do
    Rubicon::People.expects(:fire_get).with(person_invite_url).returns(nil)
    Rubicon::UntargetedInvite.find_for_person(person_id).should be_nil
  end

  it "deletes a person's invite" do
    Rubicon::People.expects(:fire_delete).with(person_invite_url)
    Rubicon::UntargetedInvite.delete_for_person(person_id)
  end
end
