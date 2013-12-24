require 'rubicon/models/profile'
require 'ladon'

module Rubicon
  module Jobs
    class FacebookExtendTokenExpiry < Ladon::Job
      acts_as_unique_job

      @queue = :facebook

      def self.work(person_id, options = {})
        with_error_handling("Exchanging Facebook authentication token", person_id: person_id) do
          profile = Profile.find_for_person_and_network(person_id, :facebook)
          if profile && profile.connected? && profile.network == :facebook
            profile.extend_token_expiry
          else
            logger.warn("Cannot update facebook token for person #{person_id}")
          end
        end
      end

      def self.include_ladon_context?
        false
      end
    end
  end
end
