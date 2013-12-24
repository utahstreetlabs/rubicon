require 'ladon/resource/base'

module Rubicon
  module Resource
    # Just here so that we can set class attributes for all Rubicon resources.
    class Base < Ladon::Resource::Base
      self.base_url = 'http://localhost:4030'

      # Force all subclasses to use the base class's base url.
      def self.base_url
        self == Base ? super : Base.base_url
      end
    end
  end
end
