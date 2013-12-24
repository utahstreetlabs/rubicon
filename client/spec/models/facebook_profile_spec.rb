require 'spec_helper'
require 'rubicon/models/facebook_profile'
require 'rubicon/models/invite'
require 'mogli'

describe Rubicon::FacebookProfile do
  let(:page) do
    stub('page', id: '34567', category: 'Page', name: 'Warhorn', picture: '//picture', link: '//link', likes: 999,
         access_token: nil)
  end
  let(:birthday) { '07/23/2012' }
  let(:location) { stub('location', name: 'The Moon') }
  let(:user) do
    stub('user', id: '67890', username: 'warhorn', name: 'Warhorn Jonez', first_name: 'Warhorn', last_name: 'Jonez',
      email: 'warhorn@warhorn.net', link: "http://graph.facebook.com/67890/picture",
      birthday: birthday, location: location, gender: 'male')
  end
  let(:follower) { Rubicon::FacebookProfile.new('_id' => 'phatpipe') }
  let(:followee) { Rubicon::FacebookProfile.new('_id' => 'deadbeef') }

  describe "#sync_attrs" do
    it "should update itself from the FB user" do
      api_user = stub('api-user')
      subject.expects(:api_user).returns(api_user)
      subject.expects(:update_from_api!).with(api_user)
      subject.sync_attrs
    end

    it "handles error when MissingUserData raised" do
      subject.expects(:api_user).raises(MissingUserData)
      subject.sync_attrs
    end
  end

  describe "#create_follow" do
    let(:rank) { stub('rank', to_params: rank_params) }
    let(:rank_params) { stub('rank-params') }

    it "creates and returns a follow" do
      follow = stub('follow')
      followee.expects(:follow_rank).with(follower).returns(rank)
      Rubicon::Follow.expects(:create).with(followee, follower, rank: rank_params).returns(follow)
      followee.create_follow(follower).should == follow
    end
  end

  describe "#follow_rank" do
    it "computes the follow rank" do
      Rubicon::FollowRank.expects(:compute).with(followee, follower)
      followee.follow_rank(follower)
    end
  end

  it "fetches api followers" do
    follower1 = stub('follower1', id: '12345')
    follower2 = stub('follower2', id: '67890')
    api_user = stub('api-user', friends: [follower1, follower2])
    subject.stubs(:api_user).returns(api_user)
    subject.fetch_api_followers.should include(follower1.id => follower1, follower2.id => follower2)
  end

  describe "#pages" do
    it "returns a page" do
      api_user = stub('api-user', accounts: [page])
      subject.stubs(:api_user).returns(api_user)
      subject.pages.should include(page)
    end

    it "does not return an application" do
      app = stub('app', category: 'Application')
      api_user = stub('api-user', accounts: [app])
      subject.stubs(:api_user).returns(api_user)
      subject.pages.should_not include(app)
    end
  end

  describe "#page_profiles" do
    before do
      subject.stubs(:pages).returns([page])
    end

    it "returns a profile for a known page" do
      profile = stub('profile', uid: page.id)
      subject.class.expects(:find_for_uids_and_network).with([page.id], :facebook).returns([profile])
      subject.class.expects(:new_from_attributes).never
      subject.page_profiles.should include(profile)
    end

    it "returns a profile for an unknown page" do
      subject.class.expects(:find_for_uids_and_network).with([page.id], :facebook).returns([])
      subject.class.expects(:new_from_attributes).with(is_a(Hash))
      subject.page_profiles.should have(1).profile
    end
  end

  it "returns attributes hash from api user" do
    attrs = subject.class.attributes_from_api(user)
    attrs['uid'].should == user.id
    attrs['username'].should == user.username
    attrs['name'].should == user.name
    attrs['first_name'].should == user.first_name
    attrs['last_name'].should == user.last_name
    attrs['email'].should == user.email
    attrs['photo_url'].should == "http://graph.facebook.com/#{user.id}/picture"
    attrs['profile_url'].should == user.link
    attrs['location'].should == location.name
    attrs['gender'].should == user.gender
    attrs['birthday'].should == Date.strptime(user.birthday, '%m/%d/%Y')
  end

  context 'location is nil' do
    let(:location) { nil }
    it 'should not explode and it should set location to nil' do
      attrs = subject.class.attributes_from_api(user)
      attrs['uid'].should == user.id
      attrs['location'].should == nil
    end
  end

  context 'birthday is nil' do
    let(:birthday) { nil }
    it 'should not explode and it should set location to nil' do
      attrs = subject.class.attributes_from_api(user)
      attrs['uid'].should == user.id
      attrs['birthday'].should == nil
    end
  end

  it "digs the profile url out of an oauth hash" do
    url = '//url'
    oauth = {'info' => {'urls' => {'Facebook' => url}}}
    subject.class.profile_url_from_oauth(oauth, :facebook).should == url
  end

  it "detects a FB anonymous email address" do
    subject.class.anonymous_email?('blahblahblah@proxymail.facebook.com').should be_true
  end

  describe "#has_live_permission?" do
    let(:api_user) { stub('api_user') }

    it "returns true when use has permission on facebook" do
      subject.expects(:api_user).returns(api_user)
      api_user.expects(:has_permission?).with(:publish_actions).returns(true)
      subject.has_live_permission?(:publish_actions).should be_true
    end

    it "raises a timeout when checking permissions takes too long" do
      subject.expects(:timeout).raises(Timeout::Error)
      expect { subject.has_live_permission?(:publish_actions) }.to raise_error(Timeout::Error)
    end
  end

  describe "#send_invitation_from" do
    let(:api_client) { stub('api_client') }
    let(:inviter) { stub('inviter', api_client: api_client, connected?: true) }
    it "should get an api client from feed and post to the subject's feed" do
      subject.expects(:post_to_feed).with(client: api_client).returns(true)
      subject.send_invitation_from(inviter, nil)
    end

    it "should raise exception when missing permissions" do
      subject.stubs(:delete_invite).returns
      subject.expects(:post_to_feed).with(client: api_client).raises(MissingPermission)
      expect { subject.send_invitation_from(inviter, nil) }.to raise_error(MissingPermission)
    end

    it "should raise exception when missing password changed" do
      subject.stubs(:delete_invite).returns
      subject.expects(:post_to_feed).with(client: api_client).raises(InvalidSession)
      expect { subject.send_invitation_from(inviter, nil) }.to raise_error(InvalidSession)
    end

    it "should raise exception when wall posts are not allowed" do
      subject.stubs(:delete_invite).returns
      subject.expects(:post_to_feed).with(client: api_client).raises(ActionNotAllowed)
      expect { subject.send_invitation_from(inviter, nil) }.to raise_error(ActionNotAllowed)
    end

    it "should raise exception when wall posts are not allowed due to rate limiting" do
      subject.stubs(:delete_invite).returns
      subject.expects(:post_to_feed).with(client: api_client).raises(RateLimited)
      expect { subject.send_invitation_from(inviter, nil) }.to raise_error(RateLimited)
    end

    it "should raise exception when access token is invalid" do
      subject.stubs(:delete_invite).returns
      subject.expects(:post_to_feed).with(client: api_client).raises(AccessTokenInvalid)
      expect { subject.send_invitation_from(inviter, nil) }.to raise_error(AccessTokenInvalid)
    end
  end

  describe "#facebook_post" do
    let(:request) { stub('request') }
    let(:response) { stub('response') }
    let(:mogli_client) { stub('api client', access_token: 'deadbeef', default_params: {}) }
    before { subject.expects(:api_client).returns(mogli_client) }

    it "returns true when successfully posting" do
      mogli_client.expects(:post).returns(true)
      subject.facebook_post({}).should == true
    end

    it "returns false when failing to post" do
      subject.stubs(:delete_invite).returns
      mogli_client.expects(:post).raises(Mogli::Client::HTTPException).twice
      subject.class.expects(:handle_error)
      subject.facebook_post({}).should == false
    end

    it "raises a MissingPermission exception when lacking permissions" do
      mogli_client.expects(:post).raises(Mogli::Client::OAuthException.new("The user hasn't authorized the application to perform this action"))
      subject.class.expects(:handle_error).never
      expect { subject.facebook_post({}) }.to raise_error(MissingPermission)
    end

    it "raises an InvalidSession exception when password changed" do
      mogli_client.expects(:post).raises(Mogli::Client::OAuthException.new("the user changed the password."))
      subject.class.expects(:handle_error).never
      expect { subject.facebook_post({}) }.to raise_error(InvalidSession)
    end

    it "raises a UserNotVisible exception when wall posts are not allowed" do
      mogli_client.expects(:post).raises(Mogli::Client::OAuthException.new("User not visible."))
      subject.class.expects(:handle_error).never
      expect { subject.facebook_post({}) }.to raise_error(ActionNotAllowed)
    end

    it "raises an OAuthException when general OAuth exception raised" do
      mogli_client.expects(:post).raises(Mogli::Client::OAuthException.new("general exception"))
      subject.class.expects(:handle_error).never
      expect { subject.facebook_post({}) }.to raise_error(AccessTokenInvalid)
    end

    it "retries successfully when a Mogli::Client::HTTPException is raised once" do
      mogli_client.expects(:post).twice.raises(Mogli::Client::HTTPException).then.returns(true)
      subject.class.expects(:handle_error).never
      subject.facebook_post({}).should be_true
    end

    it "raises an Exception when a Mogli::Client::HTTPException is raised twice" do
      mogli_client.expects(:post).raises(Mogli::Client::HTTPException).twice
      subject.class.expects(:handle_error)
      subject.facebook_post({}).should be_false
    end

    it "retries successfully when a Errno::ECONNRESET is raised once" do
      mogli_client.expects(:post).twice.raises(Errno::ECONNRESET).then.returns(true)
      subject.class.expects(:handle_error).never
      subject.facebook_post({}).should be_true
    end

    it "raises an Exception when a Errno::ECONNRESET is raised twice" do
      mogli_client.expects(:post).raises(Errno::ECONNRESET).twice
      subject.class.expects(:handle_error)
      subject.facebook_post({}).should be_false
    end

    it "raises a rate limit exception when mogli raises a feed action limit exception" do
      mogli_client.expects(:post).raises(Mogli::Client::FeedActionRequestLimitExceeded)
      subject.class.expects(:handle_error).never
      expect { subject.facebook_post({}) }.to raise_error(RateLimited)
    end

    it "raises an Exception when general exception raised" do
      subject.stubs(:delete_invite).returns
      mogli_client.expects(:post).raises(Exception)
      subject.class.expects(:handle_error)
      subject.facebook_post({}).should be_false
    end
  end

  describe "#post_to_feed" do
    let(:request) { stub('request') }
    let(:response) { stub('response') }
    let(:mogli_client) { stub('api client') }
    before { subject.expects(:api_client).returns(mogli_client) }

    it "populates the form data correctly from known attributes" do
      options = {
        message: 'message', picture: 'picture', link: 'link', name: 'name',
        caption: 'caption', description: 'description', source: 'source',
        bogus: 'bogus'
      }
      expected_options = {
        :message => 'message', :picture => 'picture', :link => 'link', :name => 'name',
        :caption => 'caption', :description => 'description', :source => 'source'
      }
      mogli_client.expects(:post).with(is_a(String), is_a(String), expected_options).returns(true)
      subject.post_to_feed(options).should == true
    end
  end

  describe '#post_notification' do
    let(:mogli_client) { stub('api client') }
    before do
      subject.expects(:api_client).returns(mogli_client)
      Rubicon.configuration.facebook_access_token = 'deadbeef'
    end

    it "populates the form data correctly from known attributes" do
      template = "ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn"
      href = '/profiles/firstname-lastname'
      ref = 'notif_type'
      access_token = 'deadbeef'
      options = { template: template, href: href, ref: ref }
      expected_options = options.merge(access_token: access_token)
      mogli_client.expects(:post).with(is_a(String), is_a(String), expected_options).returns(true)
      subject.post_notification(options).should == true
    end

    it "returns false when failing to post" do
      mogli_client.expects(:post).raises(Mogli::Client::HTTPException).twice
      subject.class.expects(:handle_error)
      subject.post_notification({}).should == false
    end
  end

  unless Rubicon.configuration.flyingdog_enabled
    describe "#extend_token_expiry" do
      let(:request) { stub('request') }
      let(:access_token) { 'deadbeef' }
      let(:expires) { 1000 }
      let(:response) { { access_token: access_token, expires: expires } }
      let(:mogli_client) { stub('api client') }
      before { subject.stubs(:uid).returns(5555) }

      it "updates token and expires when present" do
        time_now = Time.now.utc
        Timecop.freeze(time_now) do
          Mogli::Client.expects(:exchange_access_token_as_application).returns(response)
          response.expects(:symbolize_keys!)
          subject.expects(:update_attributes!)
          subject.extend_token_expiry
        end
      end

      it "does not update token and expires on exception" do
        Mogli::Client.expects(:exchange_access_token_as_application).raises(Exception)
        subject.expects(:update_attributes!).with({})
        subject.class.expects(:handle_error)
        subject.extend_token_expiry
      end
    end
  end

  describe "#post_to_ticker" do
    let(:request) { stub('request') }
    let(:response) { stub('response') }
    let(:mogli_client) { stub('api client') }
    before do
      subject.expects(:api_client).returns(mogli_client)
      subject.stubs(:uid).returns(5555)
    end

    it "populates the form data correctly from known attributes" do
      options = {
        object: 'object', link: 'link', namespace: 'namespace', action: 'action'
      }
      expected_options = {
        :params => {options[:object] => options[:link]},
        :url => "/5555/#{options[:namespace]}:#{options[:action]}",
        :message => "this is a test",
        :to => "1234567" # Facebook uid
      }
      mogli_client.expects(:post).with(expected_options[:url], is_a(String), expected_options[:params]).returns(true)
      subject.post_to_ticker(options).should == true
    end
  end

  describe "#feed_postable?" do
    subject { Rubicon::FacebookProfile.new(token: token) }
    before { subject.stubs(:identity).returns(identity) }

    context 'when connected' do
      let(:token) { '123abc' }
      let(:identity) { stub('identity', token: token) }
      its(:feed_postable?) { should be_true }
    end

    context 'when not connected' do
      let(:token) { nil }
      let(:identity) { nil }
      its(:feed_postable?) { should be_false }
    end
  end

  describe "#update_page_connections" do
    let(:batman) do
      stub('batman', id: 'batman', name: 'Batman', picture: nil, image_url: nil, link: nil, likes: '10000000',
           access_token: nil)
    end
    let(:fp) { Rubicon::FacebookProfile.new(profile_id: 123) }
    let(:pp) { Rubicon::FacebookPageProfile.new(page_params) }
    subject { fp.update_page_connections!({batman.id => connect}) }

    before do
      fp.expects(:pages).returns([batman])
      fp.expects(:page_profiles).returns([pp])
      pp.stubs(:identity).returns(nil)
    end

    context 'when connecting' do
      let(:connect) { '1' }

      context 'with a known profile' do
        let(:page_params) { {_id: 'deadbeef', uid: batman.id} }
        before do
          pp.expects(:update_from_api!).with(batman)
          pp.stubs(:identity).returns(nil)
        end

        its([:connected]) { should have(1).page_profile }
        it 'associates the profile with the page' do
          subject[:connected].first.should == pp
          pp.person_id.should == fp.person_id
        end
      end

      context 'with a new profile' do
        let(:page_params) { {uid: batman.id} }
        let(:pp2) { Rubicon::FacebookPageProfile.new(uid: pp.uid, person_id: fp.person_id) }

        before do
          pp.expects(:update_from_api!).never
          Rubicon::Profile.expects(:create_from_api!).with(fp.person_id, :facebook, batman, :page).returns(pp2)
        end

        its([:connected]) { should have(1).page_profile }
        it "associates profile with new page" do
          subject[:connected].first.should == pp2
        end
      end

      context 'with a connected profile' do
        let(:page_params) { {_id: 'deadbeef', uid: batman.id, token: 'phatpipe'} }

        before do
          pp.stubs(:identity).returns(stub('identity', token: 'phatpipe'))
          pp.expects(:update_from_api!).never
          Rubicon::Profile.expects(:create_from_api!).never
        end
        its([:connected]) { should have(0).page_profiles }
      end
    end

    context 'when disconnecting' do
      let(:connect) { '0' }
      context 'with a connected profile' do
        let(:page_params) { {_id: 'deadbeef', uid: batman.id, token: 'phatpipe'} }

        before do
          pp.stubs(:identity).returns(stub('identity', token: 'phatpipe'))
          pp.expects(:disconnect!)
        end

        its([:disconnected]) { should have(1).page_profile }
        it 'should disconnect the profile' do
          subject[:disconnected].first.should == pp
        end
      end

      context 'with an unknown profile' do
        let(:page_params) { {uid: batman.id} }

        before { pp.expects(:disconnect!).never }
        its([:disconnected]) { should have(0).page_profiles }
      end

      context 'with an unconnected profile' do
        let(:page_params) { {_id: 'deadbeef', uid: batman.id} }
        before { pp.expects(:disconnect!).never }
        its([:disconnected]) { should have(0).page_profiles }
      end
    end
  end
end
