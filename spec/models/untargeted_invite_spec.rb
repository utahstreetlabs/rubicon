require 'spec_helper'
require 'rubicon/models/untargeted_invite'

describe UntargetedInvite do
  it "allows only one untargeted invite per person" do
    existing = FactoryGirl.create(:untargeted_invite)
    duplicate = UntargetedInvite.create(person_id: existing.person_id)
    duplicate.should_not be_persisted
    duplicate.errors.should include(:person_id)
  end
end
