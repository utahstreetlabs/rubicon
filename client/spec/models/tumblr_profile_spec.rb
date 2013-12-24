require 'spec_helper'
require 'rubicon/models/profile'
require 'rubicon/models/tumblr_profile'

describe Rubicon::TumblrProfile do

  let(:token) { "tokin" }
  let(:name) { "Untitled" }
  let(:uid) { "tcopious" }
  let(:profile_url) { "http://tcopious.tumblr.com/" }
  let(:oauth) do
    {
      "provider" => "tumblr",
      "uid" => "tcopious",
      "credentials" => {
        "token" =>  token,
        "secret" => "shhhh"},
      "user_hash" => {
        "title" => "Untitled",
        "is_admin" => "1",
        "posts" => "0",
        "twitter_enabled" => "0",
        "draft_count" => "0",
        "messages_count" => "0",
        "queue_count" => "",
        "name" => "tcopious",
        "url" => "http://tcopious.tumblr.com/",
        "type" => "public",
        "followers" => "0",
        "avatar_url" => "http://assets.tumblr.com/images/default_avatar_128.gif",
        "is_primary" => "yes",
        "backup_post_limit" => "30000"},
      "info" => {
        "nickname" => "tcopious",
        "name" => "Untitled",
        "image" => "http://assets.tumblr.com/images/default_avatar_128.gif",
        "urls" => {"website" => profile_url}}
    }
  end

  let(:primary_blog) do
    {
      "name" => "lookatthislovelyhamster",
      "url" => "http://lookatthislovelyhamster.tumblr.com/",
      "title" => "Look at this Lovely Hamster",
      "primary" => 1,
      "followers" => 25,
      "tweet" => 'Y'
    }
  end

  let(:tumblr_user_info) do
    {
      "user" => {
        "following" => 263,
        "default_post_format" => "html",
        "name" => "apollo",
        "likes" => 606,
        "blogs" => [
                    {
                      "name" => "apollo",
                      "title" => "Lee Adama",
                      "url" => "http://apollo.tumblr.com/",
                      "tweet" => "auto",
                      "primary" => true,
                      "followers" => 33004929,
                    },
                   ]
      }
    }
  end

  describe '#attributes_from_oauth' do
    it 'should fill in profile url correctly' do
      attrs = Rubicon::TumblrProfile.attributes_from_oauth(oauth, :tumblr)
      attrs['profile_url'].should == profile_url
    end

    it 'should fill in the name correctly' do
      attrs = Rubicon::TumblrProfile.attributes_from_oauth(oauth, :tumblr)
      attrs['name'].should == name
    end

    it 'should fill in the uid correctly' do
      attrs = Rubicon::TumblrProfile.attributes_from_oauth(oauth, :tumblr)
      attrs['uid'].should == uid
    end

    it 'should not populate profile_url without if url missing from info hash' do
      oauth['info']['urls'].delete("website")
      attrs = Rubicon::TumblrProfile.attributes_from_oauth(oauth, :tumblr)
      attrs['profile_url'].present?.should be_false
    end
  end

  describe "#followers_count" do
    let(:followers) { {'total_users' => 1} }
    subject { Rubicon::TumblrProfile.new({'_id' => 'deadbeef'}) }

    before do
      subject.stubs(:identity).returns(nil)
      Rubicon::TumblrProfile.any_instance.stubs(:primary_blog).returns(primary_blog)
      Tumblife.any_instance.stubs(:followers).returns(followers)
    end

    its(:followers_count) { should == 1 }
  end

  describe "#sync_attrs" do
    let(:client) { stub('client') }

    before do
      subject { Rubicon::TumblrProfile.new({'_id' => 'deadbeef'}) }
      Tumblife.stubs(:new).returns(client)
    end

    it "updates attributes" do
      subject.expects(:api_user).returns(tumblr_user_info)
      subject.expects(:update_from_api!).returns
      subject.sync_attrs
    end

    it "handles error when MissingUserData raised" do
      subject.expects(:api_user).raises(MissingUserData)
      subject.sync_attrs
    end
  end

  describe "#api_followers" do
    let(:profile) { Rubicon::TumblrProfile.new({'_id' => 'deadbeef'}) }
    subject { profile.fetch_api_followers }
    before do
      Rubicon::TumblrProfile.any_instance.stubs(:primary_blog).returns(primary_blog)
      Rubicon::TumblrProfile.any_instance.stubs(:followers_count).returns(followers_count)
      Tumblife.any_instance.stubs(:followers).returns(followers)
      profile.stubs(:identity).returns(nil)
    end

    context "when there are no followers" do
      let(:followers_count) { 0 }
      let(:followers) {{'total_users' => followers_count, 'users' => []}}

      its(:count) { should == 0 }
    end

    context "when there is a follower" do
      let(:name) {'starbuck'}
      let(:followers_count) { 1 }
      let(:follower) {{'name' => 'starbuck', 'url' => 'bsg.tumblr.com'}}
      let(:followers) {{'total_users' => followers_count, 'users' => [follower]}}

      its(:count) { should == 1 }
      it { should be_a(Hash) }
      it { should  == {name => follower} }
    end
  end
end
