require 'rubicon/resource/base'

module Rubicon
  class People < Resource::Base
    def self.invite_url(id)
      "/people/#{id}/invite"
    end
  end
end
