require 'spec_helper'
require 'rack/test'
require 'rubicon/apps/people/invite'

describe Rubicon::People::InviteApp do
  include Rack::Test::Methods

  def app
    Rubicon::People::InviteApp
  end

  let(:person_id) { 5555 }

  context "GET /people/:id/invite" do
    it "returns an existing invite" do
      invite = FactoryGirl.create(:untargeted_invite, person_id: person_id)
      get "/people/#{invite.person_id}/invite"
      last_response.status.should == 200
      last_response.json[:_id].should == invite.id.to_s
    end

    it "creates and returns a new invite" do
      get "/people/#{person_id}/invite"
      last_response.status.should == 200
      last_response.json[:_id].should be
    end
  end

  context "DELETE /people/:id/invite" do
    it "deletes an existing invite" do
      invite = FactoryGirl.create(:untargeted_invite)
      delete "/people/#{invite.person_id}/invite"
      last_response.status.should == 204
      UntargetedInvite.count.should == 0
    end

    it "silently fails when invite doesn't exist" do
      delete "/people/123/invite"
      last_response.status.should == 204
    end
  end
end
