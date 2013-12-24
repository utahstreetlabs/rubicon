require 'spec_helper'
require 'rubicon/models/profile'
require 'rubicon/models/twitter_profile'
require 'twitter'

describe Rubicon::TwitterProfile do

  let(:person_id_1) { 1 }
  let(:person_id_2) { 2 }
  let(:person_uid_1) { 5555555 }
  let(:person_uid_2) { 5555556 }
  let(:network) { 'twitter' }
  let(:profile_url) { Rubicon::Profiles.profile_url(person_id_2) }
  let(:follower_url) { Rubicon::Follows.profile_follower_url(person_id_1, person_id_2) }
  let(:followers_url) { Rubicon::Profiles.profile_followers_url(person_id_1) }
  let(:followers2_url) { Rubicon::Profiles.profile_followers_url(person_id_2) }
  let(:person_network_profiles_url) { Rubicon::Profiles::person_network_profiles_url(person_id_1, network) }
  let(:network_profiles_uid_url) { Rubicon::Profiles::network_profiles_uid_url(network, person_uid_2,) }
  let(:profiles_url) { Rubicon::Profiles.profiles_url }
  let(:oauth_token) { '76377039-qgm8LU26FnkKSsvsrcOIeATii7gruGrFxeUALHM' }
  let(:oauth_token_secret) { '53m5Y8QmR75QTkVhUO9GSbazTfuoGMkBZDwhwSH4' }

  let(:fake_twitter_person) do
    {
      'id' => 5555555,
      'name' => "Kara Thrace",
      'screen_name' => 'starbuck',
      'url' => 'https://twitter.com/starbuck',
      'followers_count' => 899
    }
  end

  let(:fake_twitter_person_2) do
    {
      'id' => 5555556,
      'name' => "Lee Adama",
      'screen_name' => 'apollo',
      'url' => 'https://twitter.com/apollo',
      'followers_count' => 99
    }
  end

  let(:api) do
    {
      'id' => 5555555,
      'name' => 'Kara Thrace',
      'screen_name' => 'starbuck',
      'location' => 'New Caprica',
      'description' => 'Not a cylon',
      'url' => 'https://twitter.com/starbuck',
      'protected' => 'false',
      'followers_count' => 899,
      'friends_count' => 88,
    }
  end

  let(:fake_twitter_follower) do
    {
      'id' => 5555556,
      'name' => 'Lee Adama',
      'screen_name' => 'apollo',
      'location' => 'New Caprica',
      'description' => 'Not a cylon',
      'url' => 'https://twitter.com/apollo',
      'protected' => 'false',
      'followers_count' => 10,
      'friends_count' => 10,
    }
  end

  let(:fake_rubicon_person_1) do
    {
      'id' => 1,
      'person_id' => 1,
      'network' => 'twitter',
      'uid' => 5555555,
      'token' => oauth_token,
      'secret' => oauth_token_secret,
      'name' => 'Kara Thrace',
      'profile_url' => 'https://twitter.com/starbuck',
      'photo_url' => 'https://twitter.com/starbuck',
    }
  end

  let(:fake_rubicon_person_2) do
    {
      'id' => 2,
      'person_id' => 2,
      'network' => 'twitter',
      'uid' => 5555556,
      'name' => 'Lee Adama',
    }
  end

  let(:followers_1) { stub('follower_ids', ids: [fake_twitter_person]) }
  let(:followers_2) { stub('follower_ids', ids: [fake_twitter_person_2]) }
  let(:nofollowers) { stub('follower_ids', ids: []) }
  let(:rls) { stub('rate_limit_status', remaining_hits: 1) }

  before do
    Twitter::Client.any_instance.stubs(:authenticated?).returns(true)
    Twitter::Client.any_instance.stubs(:verify_credentials).returns(true)
    Twitter::Client.any_instance.stubs(:rate_limit_status).returns(rls)
  end

  it "returns followers count for client user" do
    Twitter::Client.any_instance.stubs(:user).returns(fake_twitter_person)
    Twitter::Client.any_instance.stubs(:get_screen_name).returns('starbuck')
    profile = Rubicon::TwitterProfile.new({'_id' => 'deadbeef', 'api_follows_count' => 899})
    profile.connection_count.should == 899
  end

  it "returns followers count for non-client user" do
    profile = Rubicon::TwitterProfile.new({'_id' => 'deadbeef', 'api_follows_count' => 99})
    profile.connection_count.should == 99
  end

  it "returns 0 followers when no followers exist" do
    profile = Rubicon::TwitterProfile.new({'_id' => 'deadbeef', 'api_follows_count' => 0})
    profile.connection_count.should == 0
  end

  context '#fetch_api_followers' do
    let(:profile) { Rubicon::TwitterProfile.new('_id' => 'deadbeef') }
    subject { profile.fetch_api_followers }

    before do
      Twitter::Client.any_instance.stubs(:follower_ids).returns(follower_ids)
      Twitter::Client.any_instance.stubs(:users).returns(users)
      profile.stubs(:identity).returns(stub('identity', token: oauth_token, secret: oauth_token_secret))
    end

    context 'and there is a follower' do
      let(:follower_ids) { followers_1 }
      let(:users) { [fake_twitter_person] }

      its(:count) { should == 1 }
    end

    context 'and there is a follower' do
      let(:follower_ids) { nofollowers }
      let(:users) { [] }

      its(:count) { should == 0 }
    end
  end

  it "returns api attributes in rubicon format" do
    data = {'uid' => 5555555, 'name' => 'Kara Thrace', 'username' => 'starbuck',
      'profile_url' => 'http://battlestar.com/starbuck', 'followers_count' => 899}
    expected = {'uid' => 5555555, 'username' => 'starbuck', 'name' => 'Kara Thrace',
      'profile_url' => 'https://twitter.com/starbuck', 'photo_url' => nil, 'api_follows_count' => 899}
    Rubicon::TwitterProfile.attributes_from_api(api).should == expected
  end

  it "guesses at a first and last name based on name" do
    p = Rubicon::TwitterProfile.new(:name => 'ham bone mccloy')
    p.first_name.should == 'ham'
    p.last_name.should == 'mccloy'
  end

  describe "#sync_attrs" do
    it "should update itself from the Twitter user" do
      api_user = stub('api-user')
      api_client = stub('api-client', current_user: api_user)
      subject.expects(:api_user).returns(api_client.current_user)
      subject.expects(:update_from_api!).with(api_user)
      subject.sync_attrs
    end

    it "handles error when MissingUserData raised" do
      subject.expects(:api_client).raises(MissingUserData)
      subject.sync_attrs
    end
  end

  describe "#post_to_feed" do
    let(:client) { mock('client') }
    let(:text) { 'That rug really tied the room together' }

    before { subject.stubs(:api_client).returns(client) }

    it "posts a status update" do
      subject.api_client.expects(:update).with(text)
      subject.post_to_feed(text: text).should be_true
    end

    it "fails to post a status update" do
      subject.api_client.expects(:update).with(text).raises("Boom")
      subject.class.expects(:handle_error)
      subject.post_to_feed(text: text).should be_false
    end

    it "barfs when text is not provided" do
      subject.api_client.expects(:update).never
      expect { subject.post_to_feed }.to raise_error(ArgumentError)
    end
  end
end
