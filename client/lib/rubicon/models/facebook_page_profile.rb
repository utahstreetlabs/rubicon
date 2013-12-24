require 'rubicon/models/profile'
require 'twitter'

module Rubicon
  class FacebookPageProfile < Profile
    def connected?
      token.present?
    end

    def connection_count
      api_follows_count != 0 ? api_follows_count : super
    end

    def fb_client
      raise NotImplementedError.new "fb_client should return a Mogli facebook client for the facebook user who added this page"
    end

    def sync_self
      update_from_api!(Mogli::Page.find(uid, Mogli::Client.new(token)))
    end

    def fetch_api_followers
      r = ActiveSupport::JSON.decode(fb_client.fql_query(api_follower_query).body)
      if r.is_a? Hash and r['error_msg']
        self.class.handle_error("Unable fetch api followers for facebook page profile #{self.uid}", r['error_msg'], r)
        {}
      else
        r.inject({}) {|m, follower| m.merge(follower['uid'] => {})}
      end
    end

    def profile_url
      profile_url ||= self.class.profile_url(self.uid)
    end

    def self.profile_url(uid)
      "http://www.facebook.com/pages/#{uid}"
    end

    def self.attributes_from_api(page, network)
      # the page object will only contain id, name and token when fetched via /me/accounts
      # it will contain extended information, but no token, when fetched via /pages/{uid}
      attrs = {
        'type' => :page,
        'uid' => page.id,
        'name' => page.name,
        'photo_url' => page.picture || page.image_url,
        'profile_url' => page.link || self.profile_url(page.id),
        'network' => network,
        'api_follows_count' => page.likes.to_i
      }
      # never set this to nil - it won't be available unless the page was fetched from the users account
      attrs['token'] = page.access_token if page.access_token
      attrs
    end

    protected

    def api_follower_query
      "SELECT uid FROM page_fan WHERE page_id='#{self.uid}' AND uid IN (SELECT uid2 FROM friend WHERE uid1 = me())"
    end
  end
end
