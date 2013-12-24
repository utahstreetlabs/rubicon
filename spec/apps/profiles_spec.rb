require 'spec_helper'
require 'rack/test'
require 'rubicon/apps/profiles'

describe Rubicon::ProfilesApp do
  include Rack::Test::Methods

  def app
    Rubicon::ProfilesApp
  end

  context "GET /people/:id/profiles" do
    let(:person_id) { '55555' }
    let(:networks) { ['twitter', 'facebook'] }
    let(:uid) { '12345' }
    before do
      networks.each {|network| FactoryGirl.create(:profile, person_id: person_id, network: network, uid: uid)}
    end

    it "returns 200" do
      do_request
      last_response.status.should == 200
    end

    it "returns the person's profiles" do
      do_request
      networks.each {|network| last_response.body.should =~ /#{network}/}
    end

    def do_request
      get "/people/#{person_id}/profiles"
    end
  end

  context 'DELETE /people/:id/registration' do
    let(:person_id) { 12345 }
    let!(:profiles) do
      ['facebook', 'twitter'].each do |network|
        FactoryGirl.create(:profile, person_id: person_id, network: network, last_name: 'garbage')
      end
    end
    before { delete "/people/#{person_id}/registration" }

    it 'returns 204' do
      expect(last_response.status).to eq(204)
    end

    it 'calls unregister! on all profiles' do
      profiles = Profile.where(person_id: person_id)
      expect(profiles).to have(2).profiles
      profiles.each do |profile|
        expect(profile.last_name).to be_nil
        expect(profile.uid).to be
      end
    end
  end

  context "GET /people/:id/profiles/:network" do
    let(:person_id) { '55555' }
    let(:network) { 'twitter' }
    let(:uid) { '12345' }
    let(:profile) { FactoryGirl.create(:profile, person_id: person_id, network: network, uid: uid) }

    it "returns 200" do
      do_request
      last_response.status.should == 200
    end

    it "returns the person's profile" do
      do_request
      last_response.body.should =~ /#{profile.network}/
    end

    it "returns 404 when the profile is not found" do
      profile.destroy
      do_request
      last_response.status.should == 404
    end

    it "returns invites embedded in the profile" do
      profile2 = FactoryGirl.create(:profile)
      profile.invites.create(inviter_id: profile2.id)
      do_request
      last_response.body.should =~ /#{profile2.id}/
    end

    def do_request
      get "/people/#{profile.person_id}/profiles/#{profile.network}"
    end

    context "when passing auth as a parameter" do
      let(:profile2) { FactoryGirl.create(:profile, person_id: person_id, network: network, uid: uid, secure: true) }

      it "returns the profile when asking for secure = true" do
        get "/people/#{profile2.person_id}/profiles/#{profile2.network}?secure=1"
        last_response.body.should =~ /#{profile2.network}/
      end

      it "does not return the profile when asking for securet = false" do
        get "/people/#{profile2.person_id}/profiles/#{profile2.network}?secure=0"
        last_response.status.should == 404
      end

      it "returns the profile when secure is not specified" do
        get "/people/#{profile2.person_id}/profiles/#{profile2.network}"
        last_response.body.should =~ /#{profile2.network}/
      end
    end
  end

  context "DELETE /people/:id/profiles/:network" do
    let(:person_id) { '55555' }
    let(:network) { 'twitter' }
    let(:uid) { '12345' }
    let(:profile) { FactoryGirl.create(:profile, person_id: person_id, network: network, uid: uid) }

    it "returns 204" do
      do_request
      last_response.status.should == 204
    end

    it "deletes the profile" do
      do_request
      lambda { Profile.find(profile.id) }.should raise_error(Mongoid::Errors::DocumentNotFound)
    end

    def do_request
      delete "/people/#{profile.person_id}/profiles/#{profile.network}"
    end
  end

  context "GET /networks/:network/profiles/:id" do
    let(:person_id) { '55555' }
    let(:network) { 'twitter' }
    let(:uid) { '12345' }
    let(:profile) { FactoryGirl.create(:profile, person_id: person_id, network: network, uid: uid) }

    it "returns 200" do
      do_request
      last_response.status.should == 200
    end

    it "returns the person's profile" do
      do_request
      last_response.body.should =~ /#{profile.network}/
    end

    it "returns 404 when the profile is not found" do
      profile.destroy
      do_request
      last_response.status.should == 404
    end

    def do_request
      get "/networks/#{profile.network}/profiles/#{profile.uid}"
    end
  end

  context "GET /networks/:network/profiles/people?person_id[]=X&person_id[]=Y" do
    let!(:profiles) do
      [FactoryGirl.create(:profile, person_id: 101, network: :facebook, type: :page, uid: '123453525'),
       FactoryGirl.create(:profile, person_id: 102, network: :facebook, type: :page, uid: '436389243'),
       FactoryGirl.create(:profile, person_id: 102, network: :twitter, type: :page, uid: '99999')]
    end

    it "returns 200" do
      do_request
      last_response.status.should == 200
    end

    it "returns the person's profile" do
      do_request
      last_response.body.should =~ /#{profiles.first.uid}/
      last_response.body.should =~ /#{profiles.second.uid}/
      last_response.body.should_not =~ /#{profiles.third.uid}/
    end

    it "returns only the profiles it can find" do
      profiles.first.destroy
      do_request
      last_response.status.should == 200
      last_response.body.should_not =~ /#{profiles.first.uid}/
      last_response.body.should =~ /#{profiles.second.uid}/
      last_response.body.should_not =~ /#{profiles.third.uid}/
    end

    def do_request
      get "/networks/#{profiles.first.network}/profiles/people/#{profiles.first.person_id};" +
        "#{profiles.second.person_id};#{profiles.third.person_id}"
    end

    it "returns an empty list if profile doesn't exist" do
      get "/networks/facebook/profiles/people/4"
      last_response.status.should == 200
      last_response.body.should == "{\"profiles\":[]}"
    end
  end

  context "GET /networks/:network/profiles?uid[]=X&uid[]=Y" do
    let(:person_id) { '55555' }
    let!(:profiles) do
      [FactoryGirl.create(:profile, person_id: person_id, network: :facebook, type: :page, uid: '123453525'),
       FactoryGirl.create(:profile, person_id: person_id, network: :facebook, type: :page, uid: '436389243')]
     end

    it "returns 200" do
      do_request
      last_response.status.should == 200
    end

    it "returns the person's profile" do
      do_request
      last_response.body.should =~ /#{profiles.first.uid}/
      last_response.body.should =~ /#{profiles.second.uid}/
    end

    it "returns only the profiles it can find" do
      profiles.first.destroy
      do_request
      last_response.status.should == 200
      last_response.body.should_not =~ /#{profiles.first.uid}/
      last_response.body.should =~ /#{profiles.second.uid}/
    end

    def do_request
      get "/networks/#{profiles.first.network}/profiles?uid[]=#{profiles.first.uid}&uid[]=#{profiles.second.uid}"
    end

    it "returns an empty list if a query string is not specified" do
      get "/networks/facebook/profiles"
      last_response.status.should == 200
      last_response.body.should == "{\"profiles\":[]}"
    end

    it "400s on bad uid params" do
      get "/networks/facebook/profiles?uid=4"
      last_response.status.should == 400
    end
  end

  describe "GET /profiles" do

    context "happily" do
      let(:profile1) { FactoryGirl.create(:profile) }
      let(:profile2) { FactoryGirl.create(:profile) }

      it "gets multiple profiles, but only those that exist" do
        bogus_id = '4e680eec50a79914b20000a6'
        get "/profiles?id[]=#{profile1.id}&id[]=#{profile2.id}&id[]=#{bogus_id}"
        last_response.status.should == 200
        last_response.body.should =~ /#{profile1.uid}/
        last_response.body.should =~ /#{profile2.uid}/
        last_response.body.should_not =~ /#{bogus_id}/
      end

      it "gets multiple profiles, but only those that exist" do
        bogus_email = 'ham@eggs.com'
        get "/profiles?email[]=#{profile1.email}&email[]=#{profile2.email}&email[]=#{bogus_email}"
        last_response.status.should == 200
        last_response.body.should =~ /#{profile1.email}/
        last_response.body.should =~ /#{profile2.email}/
        last_response.body.should_not =~ /#{bogus_email}/
      end

      it "gets multiple profiles with mixed emails and ids" do
        get "/profiles?email[]=#{profile1.email}&id[]=#{profile2.id}"
        last_response.status.should == 200
        last_response.body.should =~ /#{profile1.email}/
        last_response.body.should =~ /#{profile2.id}/
      end
    end

    it "gets no profiles when neither ids nor emails are specified" do
      get "/profiles"
      last_response.status.should == 200
      last_response.body.should == %Q/{"profiles":[]}/
    end

    it "returns bad request when malformed id is specified for multiple profiles" do
      get "/profiles?id=4"
      last_response.status.should == 400
    end
  end

  context "POST /profiles" do
    context "happily" do
      let(:person_id) { 55555 }
      let(:network) { :twitter }
      let(:uid) { '008123753830' }
      let(:entity) { {person_id: person_id, network: network, uid: uid} }

      it "returns 201" do
        do_request
        last_response.status.should == 201
      end

      it "returns the new profile" do
        do_request
        last_response.should =~ /#{person_id}/
      end

      def do_request
        post "/profiles", entity.to_json
      end
    end

    it "returns 400 when no entity is provided" do
      post "/profiles"
      last_response.status.should == 400
    end

    it "returns 400 when the entity is invalid" do
      post "/profiles", {}.to_json
      last_response.status.should == 400
    end
  end

  context "PUT /profiles/:id" do
    let(:profile) { FactoryGirl.create(:profile) }

    context "happily" do
      let(:entity) { {token: 'cafebebe', secret: 'deadbeef'} }

      it "returns 200" do
        do_request
        last_response.status.should == 200
      end

      it "returns the updated profile" do
        do_request
        last_response.should =~ /#{entity['token']}/
      end

      def do_request
        put "/profiles/#{profile.id}", entity.to_json
      end
    end

    it "returns 404 when the profile is not found" do
      profile.destroy
      put "/profiles/#{profile.id}"
      last_response.status.should == 404
    end

    it "returns 400 when no entity is provided" do
      put "/profiles/#{profile.id}"
      last_response.status.should == 400
    end

    it "returns 400 when the entity is invalid" do
      put "/profiles/#{profile.id}", {uid: nil}.to_json
      last_response.status.should == 400
    end
  end

  context "DELETE /profiles/:id" do
    let(:profile) { FactoryGirl.create(:profile) }

    it "returns 204" do
      do_request
      last_response.status.should == 204
    end

    it "deletes the profile" do
      do_request
      lambda { Profile.find(profile.id) }.should raise_error(Mongoid::Errors::DocumentNotFound)
    end

    def do_request
      delete "/profiles/#{profile.id}"
    end
  end

  context 'DELETE /profiles/:id/registration' do
    let(:person_id) { 12345 }
    let!(:profile) { FactoryGirl.create(:profile, first_name: 'Freddie', last_name: 'King') }
    before { delete "/profiles/#{profile.id}/registration" }

    it 'returns 204' do
      expect(last_response.status).to eq(204)
    end

    it 'calls unregister! on the profile' do
      profile.reload
      expect(profile.last_name).to be_nil
      expect(profile.uid).to be
    end
  end

  context "GET /profiles/:id/inviting" do
    it "404s when getting invited profiles for a nonexistent profile" do
      get "/profiles/4e775ad83cbbfc05bf000001/inviting"
      last_response.status.should == 404
    end

    it "gets profiles a profile is following" do
      profile = FactoryGirl.create(:profile)
      invited1 = FactoryGirl.create(:profile)
      invited2 = FactoryGirl.create(:profile)
      invited1.invites.create(inviter_id: profile.id)
      invited2.invites.create(inviter_id: profile.id)
      get "/profiles/#{profile.id}/inviting"
      last_response.status.should == 200
      last_response.body.should =~ /#{invited1.id}/
      last_response.body.should =~ /#{invited2.id}/
    end
  end

  it "gets a profile's followers" do
    profile = FactoryGirl.create(:profile)
    follower1 = FactoryGirl.create(:profile)
    profile.follows.create(follower_id: follower1.id)
    follower2 = FactoryGirl.create(:profile)
    profile.follows.create(follower_id: follower2.id)
    get "/profiles/#{profile.id}/followers"
    last_response.status.should == 200
    last_response.body.should =~ /#{follower1.uid}/
    last_response.body.should =~ /#{follower2.uid}/
  end

  it "gets a subset of profile's followers" do
    profile = FactoryGirl.create(:profile)
    profile2 = FactoryGirl.create(:profile)
    follower1 = FactoryGirl.create(:profile)
    profile.follows.create(follower_id: follower1.id)
    follower2 = FactoryGirl.create(:profile)
    profile.follows.create(follower_id: follower2.id)
    get "/profiles/#{profile.id}/followers?uid[]=#{profile2.id}&uid[]=#{follower1.id}"
    last_response.status.should == 200
    last_response.body.should =~ /#{follower1.uid}/
    last_response.body.should_not =~ /#{follower2.uid}/
    last_response.body.should_not =~ /#{profile2.uid}/
  end

  it "404s when getting followers for a nonexistent profile" do
    get "/profiles/4e775ad83cbbfc05bf000001/followers"
    last_response.status.should == 404
  end

  it "gets profiles a profile is following" do
    profile = FactoryGirl.create(:profile)
    followed1 = FactoryGirl.create(:profile)
    followed2 = FactoryGirl.create(:profile)
    followed1.follows.create(follower_id: profile.id)
    followed2.follows.create(follower_id: profile.id)
    get "/profiles/#{profile.id}/following"
    last_response.status.should == 200
    last_response.body.should =~ /#{followed1.uid}/
    last_response.body.should =~ /#{followed2.uid}/
  end

  it "404s when getting followers for a nonexistent profile" do
    get "/profiles/4e775ad83cbbfc05bf000001/following"
    last_response.status.should == 404
  end

  it "gets a profile's uninvited followers" do
    profile = FactoryGirl.create(:profile)
    follower1 = FactoryGirl.create(:profile)
    profile.follows.create(follower_id: follower1.id)
    follower1.invites.create(inviter_id: profile.id)
    follower2 = FactoryGirl.create(:profile)
    profile.follows.create(follower_id: follower2.id)
    get "/profiles/#{profile.id}/followers/uninvited"
    last_response.status.should == 200
    last_response.body.should_not =~ /#{follower1.id}/
    last_response.body.should =~ /#{follower2.id}/
  end

  it "404s when getting uninvited followers for a nonexistent profile" do
    get "/profiles/4e775ad83cbbfc05bf000001/followers/uninvited"
    last_response.status.should == 404
  end

  context "GET /profiles/:id/follows" do
    let(:profile1) { FactoryGirl.create(:profile) }
    let(:profile2) { FactoryGirl.create(:profile) }
    before { profile1.follows.create(follower_id: profile2.id) }

    it "returns 200" do
      do_request
      last_response.status.should == 200
    end

    it "returns the person's follows" do
      do_request
      last_response.body.should =~ /#{profile2.id}/
    end

    it "returns 404 when the profile is not found" do
      profile1.destroy
      do_request
      last_response.status.should == 404
    end

    def do_request
      get "/profiles/#{profile1.id}/follows"
    end
  end

  describe "PUT /profiles/:id/follows/:follower_id" do
    let(:profile1) { FactoryGirl.create(:profile, network: :facebook) }
    let(:profile2) { FactoryGirl.create(:profile, network: :facebook) }
    let(:rank_params) do
      { value: 2.9640000000000004,
        shared_connections_attributes: { value: 0, coefficient: 0.35 },
        network_affinity_attributes: {
          value: 4.5600000000000005, coefficient: 0.65,
          photo_tags_attributes: {value: 12, coefficient: 0.38},
          photo_annotations_attributes: {value: 0, coefficient: 0.31},
          status_annotations_attributes: {value: 0, coefficient: 0.31}
        }
      }
    end

    context "when the follow does not already exist" do
      it "creates the follow" do
        do_request
        last_response.status.should == 200
        profile1.reload
        profile1.follows.should have(1).follow
        profile1.follows.first.rank.should be
      end
    end

    context "when the follow does already exist" do
      before { profile1.follows.create(follower_id: profile2.id) }

      it "does not create a duplicate follow" do
        do_request
        profile1.reload
        profile1.follows.should have(1).follow
        profile1.follows.first.rank.should be
        profile1.follows.first.rank[:_type].should == "FacebookFollowRank"
      end
    end

    context "when the profile is not found" do
      before { profile1.destroy }

      it "returns a 404" do
        do_request
        last_response.status.should == 404
      end
    end

    def do_request
      put "/profiles/#{profile1.id}/follows/#{profile2.id}", {rank: rank_params}.to_json
    end
  end

  context "DELETE /profiles/:id/follows/:follower_id" do
    let(:profile1) { FactoryGirl.create(:profile) }
    let(:profile2) { FactoryGirl.create(:profile) }

    context 'when the follow exists' do
      before { profile1.follows.create(follower_id: profile2.id) }

      it 'should delete the follower and return 204' do
        do_request
        last_response.status.should == 204
        profile1.reload
        profile1.follows.count.should == 0
      end
    end

    it "returns 204 when the follow does not exist" do
      do_request
      last_response.status.should == 204
    end

    it "returns 404 when the profile is not found" do
      profile1.destroy
      do_request
      last_response.status.should == 404
    end

    def do_request
      delete "/profiles/#{profile1.id}/follows/#{profile2.id}"
    end
  end

  it "gets a profile" do
    profile = FactoryGirl.create(:profile)
    get "/profiles/#{profile.id}"
    last_response.status.should == 200
    last_response.json[:_id].should == profile.id.to_s
  end

  it "returns 404 when getting a profile that does not exist" do
    get "/profiles/4e63c886779a0963c4000001"
    last_response.status.should == 404
  end

  it "counts the total number of profiles" do
    profile1 = FactoryGirl.create(:profile, network: :facebook)
    profile2 = FactoryGirl.create(:profile, network: :facebook, type: :page)
    profile3 = FactoryGirl.create(:profile, network: :tumblr)
    get '/profiles/count'
    last_response.status.should == 200
    last_response.json[:count].should == 3
  end

  it "counts the number of untyped profiles for a network" do
    profile1 = FactoryGirl.create(:profile, network: :facebook)
    profile2 = FactoryGirl.create(:profile, network: :facebook, type: :page)
    profile3 = FactoryGirl.create(:profile, network: :tumblr)
    get '/networks/facebook/profiles/count'
    last_response.status.should == 200
    last_response.json[:count].should == 1
  end

  it "counts the number of typed profiles for a network" do
    profile1 = FactoryGirl.create(:profile, network: :facebook)
    profile2 = FactoryGirl.create(:profile, network: :facebook, type: :page)
    profile3 = FactoryGirl.create(:profile, network: :tumblr)
    get '/networks/facebook/profiles/count', type: :page
    last_response.status.should == 200
    last_response.json[:count].should == 1
  end

  it "deletes all untyped profiles for a network" do
    profile1 = FactoryGirl.create(:profile, network: :facebook)
    profile2 = FactoryGirl.create(:profile, network: :facebook, type: :page)
    profile3 = FactoryGirl.create(:profile, network: :tumblr)
    delete "/networks/facebook/profiles"
    last_response.status.should == 204
    Profile.count(conditions: {network: :facebook, type: nil}).should == 0
    Profile.count(conditions: {network: :facebook, type: :page}).should == 1
    Profile.count(conditions: {network: :tumblr}).should == 1
  end

  it "deletes all typed profiles for a network" do
    profile1 = FactoryGirl.create(:profile, network: :facebook)
    profile2 = FactoryGirl.create(:profile, network: :facebook, type: :page)
    profile3 = FactoryGirl.create(:profile, network: :tumblr)
    # rack-test bug - specifying params seems to set the request body
    delete "/networks/facebook/profiles?type=page"
    last_response.status.should == 204
    Profile.count(conditions: {network: :facebook, type: nil}).should == 1
    Profile.count(conditions: {network: :facebook, type: :page}).should == 0
    Profile.count(conditions: {network: :tumblr}).should == 1
  end

  it "counts the total number of follows" do
    follow1 = FactoryGirl.create(:follow)
    follow2 = FactoryGirl.create(:follow)
    get '/follows/count'
    last_response.status.should == 200
    last_response.json[:count].should == 2
  end

  context "GET /profiles/:id/inviters/following/:followee_id" do
    let(:profile) { FactoryGirl.create(:profile) }
    let(:inviter) { FactoryGirl.create(:profile) }
    let(:followee) { FactoryGirl.create(:profile) }
    before do
      profile.invites.create(inviter_id: inviter.id)
      followee.follows.create(follower_id: inviter.id)
    end

    it "returns 200" do
      get "/profiles/#{profile.id}/inviters/following/#{followee.id}"
      last_response.status.should == 200
    end

    it "returns the inviter profiles following" do
      get "/profiles/#{profile.id}/inviters/following/#{followee.id}"
      last_response.body.should =~ /#{inviter.id}/
    end

    it "returns 404 when the profile is not found" do
      profile.destroy
      get "/profiles/#{profile.id}/inviters/following/#{followee.id}"
      last_response.status.should == 404
    end

    it "only returns profiles when the inviter exists" do
      inviter.destroy
      get "/profiles/#{profile.id}/inviters/following/#{followee.id}"
      last_response.status.should == 200
      last_response.body.should_not =~ /#{inviter.id}/
    end
  end
end
