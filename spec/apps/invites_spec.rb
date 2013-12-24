require 'spec_helper'
require 'rack/test'
require 'rubicon/apps/invites'

describe Rubicon::InvitesApp do
  include Rack::Test::Methods

  def app
    Rubicon::InvitesApp
  end

  context "GET /profiles/:id/invites" do
    let(:profile1) { FactoryGirl.create(:profile) }
    let(:profile2) { FactoryGirl.create(:profile) }
    before { profile1.invites.create(inviter_id: profile2.id) }

    it "returns 200" do
      get "/profiles/#{profile1.id}/invites"
      last_response.status.should == 200
    end

    it "returns the person's invites" do
      get "/profiles/#{profile1.id}/invites"
      last_response.json[:invites].map {|i| i['_id']}.should == profile1.invites.map {|j| j.id.to_s}
    end

    it "returns 404 when the profile is not found" do
      profile1.destroy
      get "/profiles/#{profile1.id}/invites"
      last_response.status.should == 404
    end

    it "only returns invites when the inviter exists" do
      profile2.destroy
      get "/profiles/#{profile1.id}/invites"
      last_response.status.should == 200
      last_response.json[:invites].map {|i| i['_id']}.should_not == profile1.invites.map {|j| j.id.to_s}
    end
  end

  context "GET /profiles/:id/inviters" do
    let(:profile1) { FactoryGirl.create(:profile) }
    let(:profile2) { FactoryGirl.create(:profile) }
    before { profile1.invites.create(inviter_id: profile2.id) }

    it "returns 200" do
      get "/profiles/#{profile1.id}/inviters"
      last_response.status.should == 200
    end

    it "returns the person's invites" do
      get "/profiles/#{profile1.id}/inviters"
      last_response.body.should =~ /#{profile2.id}/
    end

    it "returns 404 when the profile is not found" do
      profile1.destroy
      get "/profiles/#{profile1.id}/inviters"
      last_response.status.should == 404
    end

    it "only returns profiles when the inviter exists" do
      profile2.destroy
      get "/profiles/#{profile1.id}/invites"
      last_response.status.should == 200
      last_response.body.should_not =~ /#{profile2.id}/
    end
  end

  context "PUT /profiles/:id/invites/from/:inviter_id" do
    let(:profile1) { FactoryGirl.create(:profile) }
    let(:profile2) { FactoryGirl.create(:profile) }

    it "returns 200" do
      put "/profiles/#{profile1.id}/invites/from/#{profile2.id}"
      last_response.status.should == 200
    end

    it "has one invite when the invite doesn't already exist" do
      put "/profiles/#{profile1.id}/invites/from/#{profile2.id}"
      profile1.reload
      profile1.invites.count.should == 1
    end

    it "has one invite when the invite does already exist" do
      profile1.invites.create(inviter_id: profile2.id)
      put "/profiles/#{profile1.id}/invites/from/#{profile2.id}"
      profile1.reload
      profile1.invites.count.should == 1
    end

    it "returns 404 when the profile is not found" do
      profile1.destroy
      put "/profiles/#{profile1.id}/invites/from/#{profile2.id}"
      last_response.status.should == 404
    end
  end

  context "DELETE /profiles/:id/invites/from/:inviter_id" do
    let(:profile1) { FactoryGirl.create(:profile) }
    let(:profile2) { FactoryGirl.create(:profile) }

    context "happily" do
      before { profile1.invites.create(inviter_id: profile2.id) }

      it "returns 204" do
        delete "/profiles/#{profile1.id}/invites/from/#{profile2.id}"
        last_response.status.should == 204
      end

      it "should delete the inviter" do
        delete "/profiles/#{profile1.id}/invites/from/#{profile2.id}"
        profile1.reload
        profile1.invites.count.should == 0
      end
    end

    it "returns 204 when the invite does not exist" do
      delete "/profiles/#{profile1.id}/invites/from/#{profile2.id}"
      last_response.status.should == 204
    end

    it "returns 404 when the profile is not found" do
      profile1.destroy
      delete "/profiles/#{profile1.id}/invites/from/#{profile2.id}"
      last_response.status.should == 404
    end
  end

  context "DELETE /profiles/:id/invites" do
    let(:profile1) { FactoryGirl.create(:profile) }
    let(:profile2) { FactoryGirl.create(:profile) }

    context "happily" do
      before { profile1.invites.create(inviter_id: profile2.id) }

      it "returns 204" do
        delete "/profiles/#{profile1.id}/invites"
        last_response.status.should == 204
      end

      it "should delete the inviter" do
        profile1.invites.create(inviter_id: profile2.id)
        delete "/profiles/#{profile1.id}/invites"
        profile1.reload
        profile1.invites.count.should == 0
      end
    end

    it "returns 204 when the invite does not exist" do
      delete "/profiles/#{profile1.id}/invites"
      last_response.status.should == 204
    end

    it "returns 404 when the profile is not found" do
      profile1.destroy
      delete "/profiles/#{profile1.id}/invites"
      last_response.status.should == 404
    end
  end

  context "GET /invites/:id" do
    let(:profile1) { FactoryGirl.create(:profile) }
    let(:profile2) { FactoryGirl.create(:profile) }
    let(:invite) { profile1.invites.create(inviter_id: profile2.id) }

    it "returns 200" do
      get "/invites/#{invite.id}"
      last_response.status.should == 200
    end

    it "returns 404 when the invite is not found" do
      invite.destroy
      get "/invites/#{invite.id}"
      last_response.status.should == 404
    end

    it "populates invitee in return value" do
      get "/invites/#{invite.id}"
      last_response.body.should =~ /#{profile1.id.to_s}/
    end
  end

  context "GET /invites/untargeted/:id" do
    it "returns the invite" do
      invite = FactoryGirl.create(:untargeted_invite)
      get "/invites/untargeted/#{invite.id}"
      last_response.status.should == 200
      last_response.json[:_id].should == invite.id.to_s
    end

    it 'returns 404 when the invite is not found' do
      get '/invites/untargeted/4e775ad83cbbfc05bf000001'
      last_response.status.should == 404
    end
  end
end
