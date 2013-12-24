require 'rubicon/models/profile'
require 'ladon'

module Rubicon
  module Jobs
    class SyncBase < Ladon::Job
      acts_as_unique_job

      def self.sync(profile, options = {})
        raise "Not implemented"
      end

      def self.work(person_id, network, options = {})
        uid = options[:uid]
        profile = uid ? Profile.find_for_uid_and_network(uid, network) :
          Profile.find_for_person_and_network(person_id, network)
        if profile
          if profile.connected?
            # The block provided here is used by the sync job to create a new
            # person object in the database.  We yield this block if we are importing
            # a new follower for which the network uid is not known about in rubicon.
            self.sync(profile, options)
          else
            logger.warn("Cannot sync disconnected #{network} profile #{uid} for person #{person_id}")
          end
        else
          logger.warn("Cannot sync nonexistent #{network} profile #{uid} for person #{person_id}")
        end
      end

      def self.include_ladon_context?
        false
      end
    end

    class Sync < SyncBase
      @queue = :network

      def self.sync(profile, options = {})
        profile.sync(options) { Person.create!.id }
      end
    end

    class SyncAttrs < SyncBase
      @queue = :network

      def self.sync(profile, options = {})
        profile.sync_attrs
      end
    end
  end
end
