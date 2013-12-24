require 'spec_helper'
require 'rubicon/models/profile'
require 'rubicon/models/facebook_page_profile'
require 'mogli'

describe Rubicon::FacebookPageProfile do
  describe "#sync_self" do
    it "should update itself from the FB page" do
      subject.uid = '12345'
      subject.token = 'deadbeef'
      subject.stubs(:identity).returns(stub('identity', token: 'deadbeef'))
      api_page = stub('api-page')
      Mogli::Page.expects(:find).with(subject.uid, is_a(Mogli::Client)).returns(api_page)
      subject.expects(:update_from_api!).with(api_page)
      subject.sync_self
    end
  end

  describe "#attributes_from_api" do
    it "creates a hash from a page" do
      page = Mogli::Page.new(id: 123, name: 'hams')
      Rubicon::FacebookPageProfile.attributes_from_api(page, :facebook).
        should ==({
          "type"=>:page,
          "uid"=>123,
          "name"=>"hams",
          "photo_url"=>"https://graph.facebook.com/123/picture",
          "profile_url"=>"http://www.facebook.com/pages/123",
          "network"=>:facebook,
          "api_follows_count"=>0
        })
    end
  end

  describe "#fetch_api_follower" do
    let(:response) { "[{\"uid\":764919047}]" }
    let(:fb_client) { stub('fb_client', fql_query: stub('fql response', body: response)) }
    before { subject.expects(:fb_client).returns(fb_client) }

    it "makes a fql query and parses the result into an id -> attributes hash" do
      subject.fetch_api_followers.should ==({764919047 => {}})
    end

    context "when something goes wrong" do
      let(:response) { "{\"error_code\":604,\"error_msg\":\"Can't lookup all friends of 1. Can only lookup for the logged in user (3902182), or friends of the logged in user with the appropriate permission\",\"request_args\":[{\"key\":\"method\",\"value\":\"fql.query\"},{\"key\":\"access_token\",\"value\":\"12345\"},{\"key\":\"query\",\"value\":\"SELECT uid FROM page_fan WHERE page_id='1' AND uid IN (SELECT uid2 FROM friend WHERE uid1 = 1)\"},{\"key\":\"format\",\"value\":\"json\"}]}" }

      it "should notify hoptoad and return an empty hash" do
        subject.class.expects(:handle_error)
        subject.fetch_api_followers.should ==({})
      end
    end
  end
end
