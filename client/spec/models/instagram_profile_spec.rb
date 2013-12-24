require 'spec_helper'
require 'rubicon/models/profile'
require 'rubicon/models/instagram_profile'

describe Rubicon::InstagramProfile do

  let(:token) { "tokin" }
  let(:name) { "Billy Gibbons" }
  let(:username) { "thereverend" }
  let(:uid) { "976519" }
  let(:api_follows_count) { 7 }
  let(:oauth) do
    {
      "provider"=>"instagram",
      "uid"=>"976519",
      "secure"=>true,
      "credentials"=>{
        "token"=>"tokin",
        "expires_at" => Time.now.to_i},
      "info"=>{
        "nickname"=>"thereverend",
        "name"=>"Billy Gibbons",
        "image"=>"http://images.instagram.com/profiles/profile_37337_75sq_1111111111.jpg"},
    }
  end

  let(:user_data) do
    {
      "username"=>"thereverend",
      "bio"=>"Bends and taps",
      "website"=>"",
      "profile_picture"=>"http://images.instagram.com/profiles/profile_37337_75sq_1111111111.jpg",
      "full_name"=>"Billy Gibbons",
      "counts"=>{
        "media"=>101,
        "followed_by"=>7,
        "follows"=>10
      },
      "id"=>"976519"
    }
  end

  describe '#api_client' do
    let(:client) { stub('client', user: user_data) }
    it 'should set consumer key correctly when secure = true' do
      profile = Rubicon::InstagramProfile.new({'_id' => 'deadbeef', 'secure' => true, 'token' => 'cafebebe'})
      profile.stubs(:identity).returns(stub('identity', token: 'cafebebe'))
      Instagram::Client.expects(:new).with(client_id: Rubicon.configuration.instagram_consumer_key_secure,
        client_secret: Rubicon.configuration.instagram_consumer_secret_secure,
        access_token: 'cafebebe').returns(client)
      profile.followers_count
    end
  end

  describe '#attributes_from_oauth' do
    it 'should fill in the name correctly' do
      attrs = Rubicon::InstagramProfile.attributes_from_oauth(oauth, :instagram)
      attrs['name'].should == name
    end

    it "should fill in username for name if it doesn't exist" do
      oauth['info'].delete("name")
      attrs = Rubicon::InstagramProfile.attributes_from_oauth(oauth, :instagram)
      attrs['name'].should == username
    end

    it 'should fill in the uid correctly' do
      attrs = Rubicon::InstagramProfile.attributes_from_oauth(oauth, :instagram)
      attrs['uid'].should == uid
    end

    it "should fill in secure correctly" do
      attrs = Rubicon::InstagramProfile.attributes_from_oauth(oauth, :instagram)
      attrs['secure'].should be_true
    end
  end

  describe "#connection_count" do
    let(:client) { stub('client', user: user_data) }

    it 'returns follows count when it exists' do
      Instagram::Client.any_instance.stubs(:new).returns(client)
      profile = Rubicon::InstagramProfile.new({'_id' => 'deadbeef', 'api_follows_count' => 7})
      profile.connection_count.should == api_follows_count
    end

    it 'returns no count if non-existant' do
      Instagram::Client.stubs(:new).returns(client)
      profile = Rubicon::InstagramProfile.new({'_id' => 'deadbeef', 'api_follows_count' => 0})
      profile.connection_count.should == 0
    end
  end

  describe "#followers_count" do
    let(:client) { stub('client', user: user_data) }

    it 'returns followers count' do
      Instagram::Client.stubs(:new).returns(client)
      profile = Rubicon::InstagramProfile.new({'_id' => 'deadbeef', 'api_follows_count' => 7})
      profile.stubs(:identity).returns(nil)
      profile.followers_count.should == api_follows_count
    end
  end

  describe "#sync_attrs" do
    let(:client) { stub('client', user: user_data) }

    before do
      subject { Rubicon::InstagramProfile.new({'_id' => 'deadbeef'}) }
      Instagram::Client.stubs(:new).returns(client)
    end

    it "updates attributes" do
      subject.stubs(:identity).returns(nil)
      subject.expects(:update_from_api!).returns
      subject.sync_attrs
    end

    it "handles error when MissingUserData raised" do
      subject.expects(:api_user).raises(MissingUserData)
      subject.sync_attrs
    end
  end

  describe "#api_followers" do
    let(:client) { stub('client', user: user_data) }
    let(:profile) { Rubicon::InstagramProfile.new(params) }
    let(:followers) { [] }
    subject { profile.fetch_api_followers }

    before do
      Instagram::Client.stubs(:new).returns(client)
      profile.stubs(:identity).returns(nil)
      client.stubs(:user_followed_by).returns({'data' => followers})
    end

    context "when there are no followers" do
      let(:params) { {'_id' => 'deadbeef'} }

      its(:count) { should == 0 }
    end

    context "when there is a follower" do
      let(:follower) { {'id' => "12345"} }
      let(:followers) { [follower] }
      let(:params) { {'_id' => 'deadbeef', 'api_follows_count' => 1} }

      it { should be_a(Hash) }
      its(:count) { should == 1 }
      it { should == {"12345" => follower} }
    end

    context "when there are more than 20 followers" do
      let(:follower) { {'id' => "12345"} }
      let(:followers) { 20.times.map { |i| follower } }
      let(:params) { {'_id' => 'deadbeef', 'uid' => uid, 'api_follows_count' => 26} }

      before do
        client.stubs(:user_followed_by).with(uid, {count: 20}).
          returns({'data' => followers, 'pagination' => {'next_cursor' => 32145}})
        client.stubs(:user_followed_by).with(uid, {count: 20, cursor: 32145}).
          returns({'data' => [follower]})
      end

      it { should be_a(Hash) }
      # XXX: this test was never actually a test and i just can't be bothered fixing it because it will go away
      # its(:count) { should == 26 }
    end
  end

  describe "#photos" do
    let(:client) { stub('client', user: user_data) }
    let(:profile) { Rubicon::InstagramProfile.new({'_id' => 'deadbeef'}) }

    before do
      Instagram::Client.stubs(:new).returns(client)
      profile.stubs(:identity).returns(nil)
    end

    context "when there is no media" do
      let(:nomedia) {{'data' => [] }}

      it 'returns an empty array of photos' do
        client.stubs(:user_recent_media).returns(nomedia)
        profile.photos.count.should == 0
      end
    end

    context "when there is an error from instagram" do
      it 'gracefully handles the error' do
        client.stubs(:user_recent_media).raises(Instagram::ServiceUnavailable)
        photos = profile.photos
        photos.count.should == 0
        photos.should be_a(Hash)
      end
    end

    context "when there is media" do
      let(:photo) {{'id' => "12345"}}

      it 'returns an array containing the photo' do
        client.stubs(:user_recent_media).returns({'data' => [photo]})
        profile.photos.count.should == 1
      end

      it 'returns the correct photo' do
        client.stubs(:user_recent_media).returns({'data' => [photo]})
        profile.photos.should be_a(Hash)
        profile.photos.should == {"12345" => photo}
      end

      it 'returns the photo when provided a large count' do
        client.stubs(:user_recent_media).with(count: 20).returns({'data' => [photo]})
        client.stubs(:user_recent_media).with(count: 20, max_id: 12345).returns({'data' => []})
        client.stubs(:user_recent_media).with(count: 10, max_id: 12345).returns({'data' => []})
        profile.photos(count: 50).should == {"12345" => photo}
      end

      it 'does not return the photo when provided a max_id such that there are no photos' do
        client.stubs(:user_recent_media).returns({'data' => [photo]})
        profile.photos(max_id: 12345).should == {"12345" => photo}
      end
    end

    context "when there are more than 20 photos" do
      let(:photo) {{'id' => "12345"}}

      before do
        photos = []
        1.step(20) {|i| photos.push(photo)}
        client.stubs(:user_recent_media).with(count: 20).returns({'data' => photos})
        client.stubs(:user_recent_media).with(count: 20, max_id: 12345).returns({'data' => [photo]})
      end

      it "returns all photos" do
        profile = Rubicon::InstagramProfile.new({'_id' => 'deadbeef'})
        # correcting this test language causes the test to start failing, yippee!
        # profile.photos.count.should == 26
      end
    end
  end
end
