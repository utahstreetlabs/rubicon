require 'spec_helper'
require 'rubicon/models/follow'
require 'rubicon/models/profile'

describe Profile do
  it "creates a profile for a person" do
    profile = FactoryGirl.create(:profile)
    profile.follows.count.should == 0
    profile.should be_persisted
  end

  it "does not create a profile for a person without a network" do
    profile = Profile.create(person_id: 12345, uid: '008137623759383', token: 'deadbeef')
    profile.should_not be_persisted
    profile.errors.should include(:network)
  end

  it "creates a profile with a permissions scope" do
    profile = Profile.create(person_id: 12345, uid: '008137623759383', network: 'twitter', token: 'deadbeef', secret: 'cafebebe')
    profile.should be_persisted
  end

  ### XXX we allow profiles without person_ids until we convert them to persons.
  ### This test should be put back in once we convert over to person objects
  # it "does not create a profile for a person without a person id" do
  #   profile = Profile.create(network: 'twitter', uid: '008137623759383', token: 'deadbeef')
  #   profile.should_not be_persisted
  #   profile.errors.should include(:person_id)
  # end

  it "destroys a profile for a person" do
    profile = FactoryGirl.create(:profile)
    profile.follows.count.should == 0
    profile.should be_persisted
    profile.destroy
    Profile.exists?(conditions: { id: profile.id }).should be_false
  end

  it "will not create two untyped profiles in the same network for the same user" do
    Profile.create(person_id: 12345, uid: '1', network: "facebook", type: nil).should be_persisted
    lambda { Profile.create!(person_id: 12345, uid: '2', network: "facebook", type: nil) }.should raise_exception
  end

  it "will create two typed profiles in the same network for the same user" do
    Profile.create(person_id: 12345, uid: '1', network: "facebook", type: 'page').should be_persisted
    Profile.create(person_id: 12345, uid: '2', network: "facebook", type: 'page').should be_persisted
  end

  it "will not create two profiles with different auth in the same network for the same user" do
    Profile.create(person_id: 12345, uid: '1', network: "instagram", secure: true).should be_persisted
    lambda { Profile.create!(person_id: 12345, uid: '2', network: "instagram", secure: false) }.should raise_exception
  end

  it "finds profiles a profile is inviting" do
    profile = FactoryGirl.create(:profile)
    invited1 = FactoryGirl.create(:profile)
    invited2 = FactoryGirl.create(:profile)
    invited1.invites.create!(inviter_id: profile.id)
    invited2.invites.create!(inviter_id: profile.id)
    profile.reload
    invited1.invites.count.should == 1
    invited2.invites.count.should == 1
    inviting = profile.inviting
    inviting.should have(2).items
    inviting.first.should == invited1
    inviting.last.should == invited2
  end

  it "finds profiles a profile is following" do
    profile = FactoryGirl.create(:profile)
    followed1 = FactoryGirl.create(:profile)
    followed2 = FactoryGirl.create(:profile)
    followed1.follows.create!(follower_id: profile.id)
    followed2.follows.create!(follower_id: profile.id)
    profile.reload
    following = profile.following
    following.should have(2).items
    following.first.should == followed1
    following.last.should == followed2
  end

  it "finds a profile's followers" do
    profile = FactoryGirl.create(:profile)
    follower1 = FactoryGirl.create(:profile)
    profile.follows.create!(follower_id: follower1.id)
    follower2 = FactoryGirl.create(:profile)
    profile.follows.create!(follower_id: follower2.id)
    profile.reload
    followers = profile.followers
    followers.should have(2).items
    followers.first.should == follower1
    followers.last.should == follower2
  end

  it "finds network profiles for people" do
    profile1 = FactoryGirl.create(:profile, person_id: 100, network: :facebook)
    profile2 = FactoryGirl.create(:profile, person_id: 100, network: :twitter)
    profile3 = FactoryGirl.create(:profile, person_id: 101, network: :facebook)
    profile3 = FactoryGirl.create(:profile, person_id: 101, network: :twitter)
    profile4 = FactoryGirl.create(:profile, person_id: 102, network: :facebook)
    profile5 = FactoryGirl.create(:profile, person_id: 103, network: :twitter)
    profile1.reload
    profiles = Profile.find_existing_profiles_by_person([profile1.person_id, profile2.person_id, profile3.person_id,
      profile4.person_id, profile5.person_id], :facebook)
    profiles.should have(3).items
    profiles.select { |p| p.network == :twitter }.should have(0).items
  end

  it "finds a subset of profile's followers" do
    profile = FactoryGirl.create(:profile)
    profile2 = FactoryGirl.create(:profile)
    follower1 = FactoryGirl.create(:profile)
    profile.follows.create!(follower_id: follower1.id)
    follower2 = FactoryGirl.create(:profile)
    profile.follows.create!(follower_id: follower2.id)
    profile.reload
    followers = profile.followers(uids: [follower1.id, follower2.id, profile2.id].map(&:to_s))
    followers.should have(2).items
    followers.include?(profile2).should be_false
  end

  it "limits followers found" do
    profile = FactoryGirl.create(:profile)
    follower1 = FactoryGirl.create(:profile)
    profile.follows.create!(follower_id: follower1.id)
    follower2 = FactoryGirl.create(:profile)
    profile.follows.create!(follower_id: follower2.id)
    profile.reload
    followers = profile.followers(limit: 1)
    followers.should have(1).items
  end

  it "finds followers that have been onboarded" do
    time_now = Time.now.utc
    profile = FactoryGirl.create(:profile, synced_at: time_now)
    follower1 = FactoryGirl.create(:profile, synced_at: time_now)
    follower2 = FactoryGirl.create(:profile, synced_at: time_now)
    profile.follows.create!(follower_id: follower1.id)
    profile.follows.create!(follower_id: follower2.id)
    follower3 = FactoryGirl.create(:profile)
    profile.follows.create!(follower_id: follower3.id)
    profile.reload
    followers = profile.followers(limit: 1, onboarded_only: true)
    followers.to_a.should have(1).items
  end

  it "gets the connection count of a profile's onboarded users" do
    time_now = Time.now.utc
    profile = FactoryGirl.create(:profile, synced_at: time_now)
    follower1 = FactoryGirl.create(:profile, synced_at: time_now)
    follower2 = FactoryGirl.create(:profile, synced_at: time_now)
    profile.follows.create!(follower_id: follower1.id)
    profile.follows.create!(follower_id: follower2.id)
    follower3 = FactoryGirl.create(:profile)
    profile.follows.create!(follower_id: follower3.id)
    profile.reload
    profile.connection_count!(onboarded_only: true).should == 2
  end

  it "sorts followers by friend rank" do
    profile = FactoryGirl.create(:profile)
    follower1 = FactoryGirl.create(:profile)
    profile.follows.create!(follower_id: follower1.id, rank_attributes: {value: 1})
    follower2 = FactoryGirl.create(:profile)
    profile.follows.create!(follower_id: follower2.id, rank_attributes: {value: 10})
    profile.reload
    followers = profile.followers(rank: true)
    followers.should == [follower1, follower2]
  end

  it "finds the followers a profile has without duplicates" do
     profile = FactoryGirl.create(:profile)
     follower1 = FactoryGirl.create(:profile, uid: 2)
     follow1 = profile.follows.create!(follower_id: follower1.id)
     follow1 = profile.follows.create!(follower_id: follower1.id)
     follower3 = FactoryGirl.create(:profile, uid: 3)
     profile.follows.create!(follower_id: follower3.id)
     profile.reload
     followers = profile.uninvited_followers
     followers.count.should == 2
  end


  it "finds a random subset of uninvited followers" do
    profile = FactoryGirl.create(:profile)
    10.times do
      f = FactoryGirl.create(:profile)
      profile.follows.create!(follower_id: f.id)
    end
    profile.followers.sample(5) do |f|
      f.invites.create!(inviter_id: profile.id)
    end
    profile.reload
    followers = profile.uninvited_followers(random: true, limit: 3)
    followers.should have(3).items
    followers.each do |f|
      inviter = f.invites.detect {|i| i.inviter_id == profile.id}.should be_false
      profile.followers.should include(f)
    end
  end

  it "doesn't duplicate uninvited followers when asked for more than exist" do
    profile = FactoryGirl.create(:profile)
    f1 = FactoryGirl.create(:profile)
    profile.follows.create!(follower_id: f1.id)
    f2 = FactoryGirl.create(:profile)
    profile.follows.create!(follower_id: f2.id)
    f3 = FactoryGirl.create(:profile)
    profile.follows.create!(follower_id: f3.id)
    # should get all 3 followers
    profile.reload
    followers = profile.uninvited_followers(random: 3)
    followers.should have(3).items
    followers.should include(f1, f2, f3)
    # now invite f1 - should only get f2 and f3
    f1.invites.create!(inviter_id: profile.id)
    profile.reload
    followers = profile.uninvited_followers(random: 3)
    followers.should have(2).items
    followers.should include(f2, f3)
    # now invite f2 - should only get f3
    f2.invites.create!(inviter_id: profile.id)
    profile.reload
    followers = profile.uninvited_followers(random: 3)
    followers.should have(1).item
    followers.should include(f3)
    # now invite f3 - should get no followers
    f3.invites.create!(inviter_id: profile.id)
    profile.reload
    followers = profile.uninvited_followers(random: 3)
    followers.should have(0).items
  end

  it "finds an offset subset of uninvited followers" do
    profile = FactoryGirl.create(:profile)
    10.times do
      f = FactoryGirl.create(:profile)
      profile.follows.create!(follower_id: f.id)
    end
    profile.followers.sample(5) do |f|
      f.invites.create!(inviter_id: profile.id)
    end
    profile.reload
    followers = profile.uninvited_followers(offset: 3)
    followers.should have(7).items
    followers.each do |f|
      inviter = f.invites.detect {|i| i.inviter_id == profile.id}.should be_false
      profile.followers.should include(f)
    end
  end

  it "finds the followers a profile has not invited filtered by name" do
    profile = FactoryGirl.create(:profile)
    follower1 = FactoryGirl.create(:profile, name: 'Tango')
    follow1 = profile.follows.create!(follower_id: follower1.id)
    follower2 = FactoryGirl.create(:profile, name: 'Cash')
    profile.follows.create!(follower_id: follower2.id)
    profile.reload
    followers = profile.uninvited_followers(name: "t")
    followers.should == [follower1]
  end

  it "finds profiles followed by the inviters of a profile" do
    profile = FactoryGirl.create(:profile)
    inviter1 = FactoryGirl.create(:profile)
    followee1 = FactoryGirl.create(:profile)
    follow = followee1.follows.create!(follower_id: inviter1.id)
    profile.invites.create!(inviter_id: inviter1.id)
    inviter2 = FactoryGirl.create(:profile)
    followee2 = FactoryGirl.create(:profile)
    follow = followee2.follows.create!(follower_id: inviter2.id)
    profile.invites.create!(inviter_id: inviter2.id)
    profile.reload
    profiles = profile.inviters_following(followee1.id)
    profiles.should have(1).items
    profiles.detect {|p| p.id == inviter1.id}.should be_true
    profiles.detect {|p| p.id == inviter2.id}.should be_false
  end

  it "updates last synced time correctly" do
    profile = FactoryGirl.create(:profile)
    time_now = Time.now.utc
    profile.synced_at = time_now
    profile.save
    profile.should be_persisted
    profile.reload
    profile.synced_at.utc.ctime.should == time_now.utc.ctime
  end

  it "updates expiry for oauth token correctly" do
    profile = FactoryGirl.create(:profile)
    expiry = Time.now.utc
    profile.oauth_expiry = expiry
    profile.save
    profile.should be_persisted
    profile.reload
    profile.oauth_expiry.utc.ctime.should == expiry.utc.ctime
  end

  describe '#unregister!' do
    let(:synced_at) { Time.now }
    let(:api_follows_count) { 4281 }
    let(:token) { 'somejankyoldthang' }
    let(:first_name) { 'Alicia' }
    let(:last_name) { 'Keys' }
    let(:name) { "#{first_name} #{last_name}" }
    let(:uid) { '11223344' }
    let(:network) { 'orkut' }
    subject { FactoryGirl.create(:profile, synced_at: synced_at, token: token, first_name: first_name,
                                 last_name: last_name, network: network, name: name, uid: uid,
                                 api_follows_count: api_follows_count) }
    before do
      subject.unregister!
      subject.reload
    end
    it 'removes registered user stuff' do
      [:synced_at, :api_follows_count, :token, :first_name, :last_name].each do |attr|
        expect(subject[attr.to_s]).to be_nil
      end
    end

    it 'has timestamps' do
      expect(subject.created_at).to be
      expect(subject.updated_at).to be
    end

    it 'still has a name' do
      expect(subject.name).to eq(name)
    end

    it 'still has network info' do
      expect(subject.network).to eq(network)
      expect(subject.uid).to eq(uid)
    end
  end
end
