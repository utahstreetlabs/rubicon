require 'spec_helper'
require 'rubicon/models/profile'
require 'rubicon/resource/invites'

class Rubicon::TestProfile < Rubicon::Profile
  def self.attributes_from_api(api, network)
    {'uid' => api.uid}
  end
end

describe Rubicon::Profile do
  let(:follower) { Rubicon::Profile.new('_id' => 'phatpipe') }
  let(:followee) { Rubicon::Profile.new('_id' => 'deadbeef') }

  it "typecasts network" do
    profile = Rubicon::Profile.new('network' => 'test')
    profile.respond_to?(:network).should be_true
    profile.network.should be_a(Symbol)
  end

  context "#has_permission?" do
    let(:scope) { 'email' }
    let(:profile) { Rubicon::Profile.new('network' => 'test', 'scope' => scope) }
    before { profile.stubs(:identity).returns(stub('identity', scope: scope)) }

    it 'responds to has_permission?' do
      profile.respond_to?(:has_permission?).should be_true
    end

    it 'returns true for present permissions' do
      profile.has_permission?(:email).should be_true
    end

    it "returns false for missing permissions" do
      profile.has_permission?(:offline_access).should be_false
    end
  end

  it "updates a profile from OAuth" do
    profile = Rubicon::Profile.new('_id' => 12345, 'network' => 'twitter', 'uid' => '00128347372')
    oauth = stub('oauth')
    attrs = {}
    Rubicon::Profile.expects(:attributes_from_oauth).with(oauth, profile.network).returns(attrs)
    profile.expects(:update_attributes!).returns(true)
    profile.update_from_oauth!(oauth).should be_true
  end

  describe "#find_or_create!" do
    let(:person_id) { 10 }
    let(:network) { 'twitter' }
    let(:uid) { '123454321' }
    let(:profile) { Rubicon::Profile.new('_id' => 'cafebebe', 'person_id' => person_id, 'network' => network,
      'uid' => uid) }

    context 'when a profile exists' do
      before { Rubicon::Profile.expects(:find_for_uid_and_network).with(uid, network).returns(profile) }
      subject { Rubicon::Profile.find_or_create!(person_id, network, uid) }

      context 'that is attached to the requesting person' do
        before { profile.expects(:update_attribute!).never }
        it { should == profile }
      end

      if Rubicon.configuration.flyingdog_enabled
        context 'that is attached to a different person' do
          let(:new_person_id) { 11 }
          subject { Rubicon::Profile.find_or_create!(new_person_id, network, uid, reassign: reassign) }

          context 'with reassign = true' do
            let(:reassign) { true }
            before do
              profile.expects(:update!)
            end

            it { should == profile }
            its(:person_id) { should == new_person_id }
          end

          context 'with reassign = false' do
            let(:reassign) { false }
            before do
              profile.expects(:update!).never
            end

            it { should == profile }
            its(:person_id) { should == person_id }
          end
        end
      end
    end

    context 'when no profile exists' do
      let(:network_class) { stub('class') }
      it "creates a new profile" do
        Rubicon::Profile.expects(:find_for_uid_and_network).with(uid, network).returns(nil)
        Rubicon::Profile.expects(:profile_class).with(network).returns(network_class)
        network_class.expects(:create!).with(person_id, network, uid: uid)
        Rubicon::Profile.find_or_create!(person_id, network, uid)
      end
    end
  end

  context "#valid_credentials?" do
    let(:oldtoken) { 'deadbeef' }
    let(:oldsecret) { 'cafebebe' }
    let(:newtoken) { 'newtoken' }
    let(:newsecret) { 'newsecret' }

    context "when token and secret are required" do
      let(:user_info) { { 'uid' => '12345' } }

      before do
        subject.stubs(:token).returns(oldtoken)
        subject.stubs(:secret).returns(oldsecret)
        subject.stubs(:uid).returns(user_info['uid'])
      end

      it "returns true if both token and secret match stored" do
        subject.expects(:api_user).never
        subject.valid_credentials?(token: oldtoken, secret: oldsecret).should be_true
      end

      context "when connecting with new credentials" do
        it "returns true when the uid matches the one stored for the profile" do
          subject.stubs(:uid).returns(user_info['uid'])
          subject.expects(:api_user).with(token: newtoken, secret: newsecret).returns(user_info)
          subject.class.expects(:attributes_from_api).with(user_info).returns(user_info)
          subject.valid_credentials?(token: newtoken, secret: newsecret).should be_true
        end

        it "returns true when the uids match when normalized" do
          subject.stubs(:uid).returns(user_info['uid'].to_i)
          subject.expects(:api_user).with(token: newtoken, secret: newsecret).returns(user_info)
          subject.class.expects(:attributes_from_api).with(user_info).returns(user_info)
          subject.valid_credentials?(token: newtoken, secret: newsecret).should be_true
        end

        it "returns false when the uid doesn't match the one stored for the profile" do
          subject.stubs(:uid).returns(nil)
          subject.expects(:api_user).with(token: newtoken, secret: newsecret).returns(user_info)
          subject.class.expects(:attributes_from_api).with(user_info).returns(user_info)
          subject.valid_credentials?(token: newtoken, secret: newsecret).should be_false
        end
      end

      it "returns false if we can't connect with new credentials" do
        subject.expects(:api_user).with(token: newtoken, secret: newsecret).returns(nil)
        subject.valid_credentials?(token: newtoken, secret: newsecret).should be_false
      end

      it "returns false if MissingUserData exception raised" do
        subject.expects(:api_user).with(token: newtoken, secret: newsecret).raises(MissingUserData)
        subject.valid_credentials?(token: newtoken, secret: newsecret).should be_false
      end

      it "returns true if missing token and secret" do
        subject.expects(:api_user).with(token: newtoken, secret: newsecret).never
        subject.valid_credentials?(token: nil, secret: nil).should be_true
      end
    end

    context "when only a token is required" do
      let(:user_info) { { 'uid' => '23456' } }

      before do
        subject.stubs(:token).returns(oldtoken)
      end

      it "returns true if both token matches stored" do
        subject.expects(:api_user).never
        subject.valid_credentials?(token: oldtoken).should be_true
      end

      context "when connecting with new credentials" do
        it "returns true when the uid matches the one stored for the profile" do
          subject.stubs(:uid).returns(user_info['uid'])
          subject.expects(:api_user).with(token: newtoken).returns(user_info)
          subject.class.expects(:attributes_from_api).with(user_info).returns(user_info)
          subject.valid_credentials?(token: newtoken).should be_true
        end

        it "returns false when the uid doesn't match the one stored for the profile" do
          subject.stubs(:uid).returns(nil)
          subject.expects(:api_user).with(token: newtoken).returns(user_info)
          subject.class.expects(:attributes_from_api).with(user_info).returns(user_info)
          subject.valid_credentials?(token: newtoken).should be_false
        end
      end

      it "returns false if we can't connect with new credentials" do
        subject.expects(:api_user).with(token: newtoken).returns(nil)
        subject.valid_credentials?(token: newtoken).should be_false
      end

      it "returns false if MissingUserData exception raised" do
        subject.expects(:api_user).with(token: newtoken).raises(MissingUserData)
        subject.valid_credentials?(token: newtoken).should be_false
      end
    end
  end

  context "#update_attributes!" do
    let(:attrs) { { foo: :bar, baz: :quux } }

    it "updates all attributes" do
      subject.expects(:attributes=).with(attrs)
      subject.expects(:update!).once
      subject.update_attributes!(attrs)
    end

    context "when updating expiration of oauth tokens" do

      let(:old_expiry) { Time.now.utc }

      it "does not update oauth_expiry if less than stored expiry" do
        new_expiry = Time.at(old_expiry - 1000)
        subject.expects(:attributes=).once
        subject.expects(:update!).once
        subject.stubs(:oauth_expiry).returns(old_expiry.to_datetime)
        subject.update_attributes!(attrs.merge({'oauth_expiry' => new_expiry}))
      end

      it "updates oauth_expiry if greater than stored expiry" do
        new_expiry = Time.at(old_expiry + 1000)
        attrs.merge!({'oauth_expiry' => new_expiry})
        subject.expects(:attributes=).with(attrs)
        subject.expects(:update!).once
        subject.stubs(:oauth_expiry).returns(old_expiry.to_datetime)
        subject.update_attributes!(attrs)
      end

      it "updates oauth_expiry if no old expiry present" do
        new_expiry = Time.at(old_expiry - 1000)
        attrs.merge!({'oauth_expiry' => new_expiry})
        subject.expects(:attributes=).with(attrs)
        subject.expects(:update!).once
        subject.stubs(:oauth_expiry).returns(nil)
        subject.update_attributes!(attrs)
      end
    end
  end

  describe '#can_disconnect?' do
    subject { Rubicon::Profile.new(params) }
    let(:identity) { params.empty?? nil : stub('identity', params) }
    before { subject.stubs(:identity).returns(identity) }

    context 'with credentials' do
      let(:params) { {'token' => 'deadbeef', 'secret' => 'cafebebe'} }
      its(:can_disconnect?) { should be_true }
    end

    context 'without credentials' do
      let(:params) { {} }
      its(:can_disconnect?) { should be_false }
    end
  end

  it "returns true when successfully disconnecting a profile" do
    profile = Rubicon::Profile.new('_id' => 'deadbeef')
    Rubicon::Profiles.expects(:fire_put).with(is_a(String), {:token => nil, :secret => nil, :scope => nil}).returns(true)
    profile.disconnect!.should be_true
  end

  it "returns false when unsuccessfully disconnecting a profile" do
    profile = Rubicon::Profile.new('_id' => 'deadbeef')
    Rubicon::Profiles.expects(:fire_put).returns(false)
    profile.disconnect!.should be_false
  end

  it "can delete an existing profile" do
    profile = Rubicon::Profile.new({'_id' => 'deadbeef', 'person_id' => 1, 'network' => 'twitter'})
    Rubicon::Profiles.expects(:fire_delete).returns
    Rubicon::Profile.delete!(profile.person_id, profile.network)
  end

  describe "#followed_by?" do
    it "returns true when follower exists" do
      Rubicon::Follow.expects(:find_by_followee_and_follower).with(followee, follower).returns(true)
      followee.should be_followed_by(follower)
    end

    it "returns false when follower doesn't exist" do
      Rubicon::Follow.expects(:find_by_followee_and_follower).with(followee, follower).returns(false)
      followee.should_not be_followed_by(follower)
    end
  end

  describe "#follows_in" do
    it "returns the subset of profiles that are followers" do
      profile = Rubicon::Profile.new('network' => 'facebook', '_id' => 'deadbeef')
      Rubicon::Profiles.expects(:fire_get).returns({"profiles" => [{'network' => 'facebook', '_id' => 'deadbeef'}]})
      followee.follows_in([profile]).count.should == 1
    end

    it "returns an empty array if no uids are specified" do
      Rubicon::Profiles.expects(:fire_get).never
      followee.follows_in([]).count.should == 0
    end
  end

  describe "#missing_live_permissions" do
    it "returns an empty set of permissions if no permissions are asked for" do
      subject.expects(:has_live_permission?).never
      subject.missing_live_permissions([]).should == []
    end

    it "returns the array of missing permissions" do
      subject.expects(:has_live_permission?).with(:read).returns(true)
      subject.expects(:has_live_permission?).with(:write).returns(false)
      subject.missing_live_permissions([:read, :write]).should == [:write]
    end
  end

  describe "#create_follow" do
    it "creates and returns a follow" do
      follow = stub('follow')
      Rubicon::Follow.expects(:create).with(followee, follower, {}).returns(follow)
      followee.create_follow(follower).should == follow
    end
  end

  describe "#delete_follow" do
    it "destroys the follow" do
      Rubicon::Follow.expects(:destroy).with(followee, follower)
      followee.delete_follow(follower)
    end
  end

  it "returns number of followers when profile exists" do
    profile = Rubicon::Profile.new('network' => 'twitter', '_id' => 'deadbeef')
    url = Rubicon::Profiles.profile_followers_url(profile.id)
    Rubicon::Profiles.expects(:fire_get).with(url, is_a(Hash)).
      returns('profiles' => [{'_id' => 'phatpipe', 'network' => 'twitter'}])
    profile.followers.count.should == 1
  end

  describe "#inviting" do
    it "returns number of inviting profiles when profile exists" do
      profile = Rubicon::Profile.new('network' => 'facebook', '_id' => 'deadbeef')
      url = Rubicon::Profiles.profile_inviting_url(profile.id)
      Rubicon::Profiles.expects(:fire_get).with(url, is_a(Hash)).
        returns('profiles' => [{'_id' => 'phatpipe', 'network' => 'facebook'}])
      profile.inviting.should have(1).profile
    end
  end

  describe "#inviting_count" do
    it "returns count of inviting profiles" do
      subject.expects(:inviting).returns([:foo, :bar, :baz])
      subject.inviting_count.should == 3
    end
  end

  describe "#expiry_from_oauth" do
    it "returns a DateTime when expires_at present in credentials" do
      expiry = Time.now.to_i
      subject.class.expiry_from_oauth({'credentials' => {'expires_at' => expiry }}).is_a?(DateTime).should be_true
    end
  end

  it "returns number of following profiles when profile exists" do
    profile = Rubicon::Profile.new('network' => 'twitter', '_id' => 'deadbeef')
    url = Rubicon::Profiles.profile_following_url(profile.id)
    Rubicon::Profiles.expects(:fire_get).with(url, is_a(Hash)).
      returns('profiles' => [{'_id' => 'phatpipe', 'network' => 'twitter'}])
    profile.following.should have(1).profile
  end

  it "returns number of uninvited followers when profile exists" do
    profile = Rubicon::Profile.new('network' => 'twitter', '_id' => 'deadbeef')
    url = Rubicon::Profiles.profile_followers_uninvited_url(profile.id)
    Rubicon::Profiles.expects(:fire_get).with(url, is_a(Hash)).
      returns('profiles' => [{'_id' => 'phatpipe', 'network' => 'twitter'}])
    profile.uninvited_followers.should have(1).profile
  end

  it "returns number of follows when profile exists" do
    profile = Rubicon::Profile.new('network' => 'facebook', '_id' => 'deadbeef')
    follower_id = 'cafebebe'
    Rubicon::Follow.expects(:find_all_by_followee).with(profile).
      returns([Rubicon::Follow.new(follower_id: follower_id)])
    follows = profile.follows
    follows.count.should == 1
    follows.first.follower_id.should == follower_id
  end

  it "creates a profile from OAuth" do
    oauth = {
      'uid' => 'starbuck',
      'info' => {
        'name' => 'Kara Thrace',
        'first_name' => 'Kara',
        'last_name' => 'Thrace',
        'email' => 'starbuck@galactica.mil',
        'image' => 'http://example.com/photos/starbuck.jpg',
        'urls' => {
          'Test' => 'http://example.com/starbuck',
        }
      },
      'credentials' => {
        'token' => 'cafebebe',
        'secret' => 'deadbeef',
      },
      'scope' => "read,write"
    }
    Rubicon::Profiles.expects(:fire_post).returns('uid' => oauth['uid'], 'scope' => oauth['scope'])
    profile = Rubicon::Profile.create_from_oauth!(123, :test, oauth)
    profile.stubs(:identity).returns(stub('identity', scope: oauth['scope']))
    profile.should be_a(Rubicon::TestProfile)
    profile.uid.should == oauth['uid']
    profile.scope.should == oauth['scope']
  end

  it "creates a profile from api" do
    api = stub('api', uid: 'starbuck')
    Rubicon::Profiles.expects(:fire_post).returns('uid' => api.uid)
    profile = Rubicon::Profile.create_from_api!(123, :test, api)
    profile.should be_a(Rubicon::TestProfile)
    profile.uid.should == api.uid
  end

  it "finds all profiles for a person" do
    person_id = 12345
    Rubicon::Profiles.expects(:fire_get).returns('profiles' => [{'network' => 'twitter'}])
    Rubicon::Profile.find_all_for_person(person_id).should have(1).profile
  end

  it "finds an existing profile by person and network" do
    person_id = 12345
    network = 'twitter'
    Rubicon::Profiles.expects(:fire_get).returns({'network' => 'twitter'})
    Rubicon::Profile.find_for_person_or_uid_and_network(person_id, nil, network).should be_a(Rubicon::Profile)
  end

  it "finds a set of profiles by person id and network" do
    network = 'twitter'
    Rubicon::Profiles.expects(:fire_get).returns('profiles' => [{'network' => 'twitter'}])
    Rubicon::Profile.find_for_people_and_network([100, 101], network).first.should be_a(Rubicon::Profile)
  end

  it "does not find a nonexistent profile by person and network" do
    person_id = 12345
    network = 'twitter'
    Rubicon::Profiles.expects(:fire_get).returns(nil)
    Rubicon::Profile.find_for_person_or_uid_and_network(person_id, nil, network).should be_nil
  end

  it "finds an existing profile by uid and network" do
    uid = 12345
    network = 'twitter'
    Rubicon::Profiles.expects(:fire_get).returns({'network' => 'twitter'})
    Rubicon::Profile.find_for_person_or_uid_and_network(nil, uid, network).should be_a(Rubicon::Profile)
  end

  it "does not find a nonexistent profile by person and network" do
    uid = 12345
    network = 'twitter'
    Rubicon::Profiles.expects(:fire_get).returns(nil)
    Rubicon::Profile.find_for_person_or_uid_and_network(nil, uid, network).should be_nil
  end

  it "creates a new profile by person_id and network" do
    person_id = 12345
    network = 'twitter'
    Rubicon::Profiles.expects(:fire_post).returns({'network' => 'twitter'})
    Rubicon::Profile.create!(person_id, network).should be_a(Rubicon::Profile)
  end

  it "updates an existing profile by person_id and network" do
    profile = Rubicon::Profile.new('person_id' => 12345, 'network' => 'twitter')
    profile.expects(:update_attributes!).returns(true)
    profile.update_from_oauth!({'id' => 56789}).should be_true
  end

  unless Rubicon.configuration.flyingdog_enabled
    context "when updating scope" do
      it "updates an existing profile without a scope with new scope" do
        profile = Rubicon::Profile.new('person_id' => 12345, 'network' => 'twitter')
        profile.expects(:changed?).returns(true)
        Rubicon::Profiles.expects(:fire_put).returns(true)
        profile.update_from_oauth!({'id' => 56789, 'scope' => 'read'}).should be_true
        profile.scope.should == 'read'
      end

      it "updates an existing profile with a scope with new scope, without duplicates" do
        profile = Rubicon::Profile.new('person_id' => 12345, 'network' => 'twitter', 'scope' => 'foo,bar,baz')
        profile.expects(:changed?).returns(true)
        Rubicon::Profiles.expects(:fire_put).returns(true)
        profile.update_from_oauth!({'id' => 56789, 'scope' => 'bar,baz,quux'}).should be_true
        profile.scope.split(%r{,\s*}).sort.should == ['bar','baz','foo','quux']
      end
    end
  end

  context "when syncing" do
    let(:api_attrs) { {'uid' => '1234'} }
    subject { Rubicon::Profile.new({'_id' => 'deadbeef', 'network' => ''}) }

    before do
      follower.stubs(:uid).returns(api_attrs['uid'])
      subject.stubs(:connected?).returns(true)
      subject.stubs(:update!).returns
      subject.stubs(:sync_attrs).returns
    end

    context "an existing api follower" do
      before do
        subject.stubs(:fetch_api_followers).returns({api_attrs['uid'] => api_attrs})
        subject.stubs(:followers).returns([])
        subject.stubs(:find_or_create_follower_profile).with(api_attrs['uid'], api_attrs).returns(follower)
      end

      it "creates a follow when one does not already exist" do
        subject.expects(:followed_by?).with(follower).returns(false)
        subject.expects(:create_follow).with(follower).returns(stub('follow'))
        subject.sync
      end

      it "does not create a follow when one already exists" do
        subject.expects(:followed_by?).with(follower).returns(true)
        subject.expects(:create_follow).never
        subject.sync
      end
    end

    context "no api followers" do
      before do
        subject.expects(:fetch_api_followers).returns({})
        subject.expects(:followers).returns([follower])
      end

      it "deletes an existing follow" do
        subject.expects(:delete_follow).with(follower)
        subject.sync
      end
    end
  end

  context "when updating attributes from api" do
    let(:api_attrs) { {'uid' => '1234'} }
    subject { Rubicon::Profile.new({'_id' => 'deadbeef', 'network' => ''}) }

    before do
      Rubicon::Profile.stubs(:attributes_from_api).returns(api_attrs)
    end

    it "updates the last synced time" do
      subject.expects(:update!).returns(true)
      time_now = Time.now.utc
      Timecop.freeze(time_now) do
        subject.update_from_api!(api_attrs)
        subject.synced_at.ctime.should == time_now.ctime
      end
    end
  end

  describe '#find_for_uids_and_network' do
    let (:profiles) { Rubicon::Profile.find_for_uids_and_network([1, 2], :facebook) }
    before do
      Rubicon::Profiles.expects(:fire_get).returns('profiles' => [{'_id' => 1, 'uid' => '1', 'network' => 'facebook', 'type' => 'page'}])
    end
    it "finds existing profiles" do
      profiles.find {|p| p.uid == '1'}.should be_persisted
    end
  end

  describe '#find' do
    let(:profile1) { {'id' => 'cafebebe', 'name' => 'Tony Hamza', 'network' => 'facebook'} }
    let(:profile2) { {'id' => 'deadbeef', 'name' => 'Alyssa Milano', 'network' => 'facebook'} }

    it "finds one profile" do
      id = profile1['id']
      url = Rubicon::Profiles.profile_url(id)
      Rubicon::Profiles.expects(:fire_get).with(url, has_entry(params: {})). returns(profile1)
      Rubicon::Profile.find(id).name.should == profile1['name']
    end

    it "finds multiple profiles" do
      ids = [profile1['id'], profile2['id']]
      url = Rubicon::Profiles.profiles_url
      Rubicon::Profiles.expects(:fire_get).with(url, has_entry(params: {'id[]' => ids})).
        returns({'profiles' => [profile1, profile2]})
      profiles = Rubicon::Profile.find(ids)
      profiles.should have(2).profiles
      profiles.first.name.should == profile1['name']
      profiles.last.name.should == profile2['name']
    end
  end

  describe '#find_by_email' do
    let(:profile1) { {'id' => 'cafebebe', 'name' => 'Tony Hamza', 'network' => 'facebook', 'email' => 'tony@hamza.com'} }
    let(:profile2) { {'id' => 'deadbeef', 'name' => 'Alyssa Milano', 'network' => 'facebook', 'email' => 'alyssa@milano.com'} }

    it "finds multiple profiles" do
      emails = [profile1['email'], profile2['email']]
      url = Rubicon::Profiles.profiles_url
      Rubicon::Profiles.expects(:fire_get).with(url, has_entry(params: {'email[]' => emails})).
        returns({'profiles' => [profile1, profile2]})
      profiles = Rubicon::Profile.find_by_email(emails)
      profiles.should have(2).profiles
      profiles.first.name.should == profile1['name']
      profiles.last.name.should == profile2['name']
    end
  end

  it "contains invites" do
    invitee_id = 'phatpipe'
    inviter_id = 'deadbeef'
    profile = Rubicon::Profile.new('_id' => invitee_id, 'invites' => [{'inviter_id' => inviter_id}])
    profile.should be_invited
    profile.should be_invited_by(inviter_id)
  end

  it "creates an invite" do
    inviter = Rubicon::Profile.new('_id' => 'phatpipe')
    invitee = Rubicon::Profile.new('_id' => 'deadbeef')
    url = Rubicon::Invites.invites_from_url(invitee.id, inviter.id)
    Rubicon::Invites.expects(:fire_put).with(url, is_a(Hash)).returns({})
    invite = invitee.create_invite_from(inviter)
    invite.inviter_id.should == inviter.id
    invite.invitee_id.should == invitee.id
    invitee.should be_invited
    invitee.should be_invited_by(inviter.id)
  end

  it "deletes an invite" do
    inviter = Rubicon::Profile.new('_id' => 'phatpipe')
    invitee = Rubicon::Profile.new('_id' => 'deadbeef')
    url = Rubicon::Invites.invites_from_url(invitee.id, inviter.id)
    Rubicon::Invites.expects(:fire_put).with(url, is_a(Hash)).returns({})
    invite = invitee.create_invite_from(inviter)
    invite.inviter_id.should == inviter.id
    invite.invitee_id.should == invitee.id
    invitee.should be_invited
    invitee.should be_invited_by(inviter.id)
    Rubicon::Invites.expects(:fire_delete).with(url)
    invitee.delete_invite(invite)
    invitee.should_not be_invited
    invitee.should_not be_invited_by(inviter.id)
  end

  describe "inviters following tests" do
    let(:profile) { Rubicon::Profile.new('_id' => 'phatpipe') }
    let(:invitee) { Rubicon::Profile.new('_id' => 'deadbeef') }

    context "given profiles" do
      it "returns the list of inviter profiles also following followee" do
        Rubicon::Profiles.expects(:fire_get).returns('profiles' => [{'_id' => 'phatpipe', 'network' => 'facebook'}])
        invitee.inviters_following(profile).should be_a(Array)
      end
    end

    context "given profile ids" do
      it "returns the list of inviter profiles also following followee" do
        Rubicon::Profiles.expects(:fire_get).returns('profiles' => [{'_id' => 'phatpipe', 'network' => 'facebook'}])
        invitee.inviters_following(profile.id).should be_a(Array)
      end
    end
  end

  describe '.connection_count' do
    it 'returns connection count when present' do
      profile = Rubicon::Profile.new(connection_count: 3)
      profile.connection_count.should == 3
    end

    it 'defaults to api_follows_count when connection count is nil' do
      profile = Rubicon::Profile.new(api_follows_count: 3)
      profile.connection_count.should == 3
    end
  end

  describe '#unregister!' do
    let(:profile_id) { 'beefcafe' }
    let(:profile) { Rubicon::Profile.new('_id' => profile_id) }
    it 'unregisters the profile' do
      Rubicon::Profiles.expects(:fire_delete).
        with(Rubicon::Profiles.profile_registration_url(profile_id), raise_on_error: true).returns(nil)
      profile.unregister!
    end
  end
end
