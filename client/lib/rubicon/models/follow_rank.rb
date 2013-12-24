require 'redhook/models/connection'
require 'active_support/core_ext/numeric/time'

module Rubicon
  # Represents the FollowRank of +p+ relative to +u+. See
  # https://wiki.copious.com/display/ENG/Invite+Follows#InviteFriends-%22FriendRank%22algorithm for more information
  # on FollowRank.
  #
  # This class is not meant to be used directly by consumers. The subclasses which specialize it for specific
  # networks (e.g. +FacebookFollowRank+) should be used instead.
  class FollowRank < Ladon::Model
    attr_accessor :value, :shared_connections, :network_affinity

    def initialize(attrs = {})
      super(attrs.reject {|key, value| [:_type, :shared_connections, :network_affinity].include?(key.to_sym)})
      @shared_connections = FollowRankSharedConnections.new(config, attrs.fetch('shared_connections', {}))
      @network_affinity = self.class.build_network_affinity(config, attrs.fetch('network_affinity', {}))
    end

    # Computes and returns FR(u, p) and sets +value+, +shared_connections+ and +network_affinity+.
    def compute(u, p)
      self.value = shared_connections.compute(u, p) * shared_connections.coefficient +
        network_affinity.compute(u, p) * network_affinity.coefficient
    end

    def config
      Rubicon.configuration.follow_rank.send(self.class.network.to_sym)
    end

    def to_params
      {
        value: value,
        shared_connections_attributes: shared_connections.to_params,
        network_affinity_attributes: network_affinity.to_params
      }
    end

    # Instantiates and returns a +FollowRank+ instance for the given network.
    def self.new_from_attributes(attrs = {})
      type = attrs['_type']
      case type.to_sym
      when FacebookFollowRank._type then FacebookFollowRank.new(attrs)
      else raise "Not implemented for #{type}"
      end
    end

    # Instantiates and returns a +FollowRank+ instance with value computed relative to +u+ and +p+.
    def self.compute(u, p)
      rank = case u.network.to_sym
      when FacebookFollowRank.network then FacebookFollowRank.new
      else raise "Not implemented for #{u.network}"
      end
      rank.compute(u, p)
      rank
    end

    def self.build_network_affinity
      raise "Not implemented"
    end

    def self.network
      raise "Not implemented"
    end
  end

  class FollowRankMetadata < Ladon::Model
    attr_accessor :config, :value, :coefficient

    def initialize(config, attrs = {})
      super(attrs.reject {|key, value| [:_type].include?(key.to_sym)})
      @config = config
    end

    def to_params
      {value: value, coefficient: coefficient}
    end

    # Returns true if +time_str+ represents a timestamp within the previous +window+ days.
    def self.in_time_window(time_str, window)
      t = Time.parse(time_str) if time_str
      t and t >= Time.now.ago(window * 24 * 60 * 60)
    end
  end

  class FollowRankSharedConnections < FollowRankMetadata
    def initialize(config, attrs = {})
      super(config, attrs)
      @coefficient = config.shared_connections_coefficient
    end

    # Computes and returns SC(u, p), setting +value+.
    def compute(u, p)
      # XXX: this is killing redhook and it's surely something that could be done more efficiently.
      # so taking it out to manage our queues while we figure out a better way
      # rh = Redhook::Connection.find(u.person_id, [p.person_id]).values.first
      # self.value = rh ? rh[:paths].size : 0
      # logger.debug("Shared Copious connections for #{u.id} and #{p.id}: #{value}")
      self.value = 0
      value
    end
  end

  class FollowRankNetworkAffinity < FollowRankMetadata
    def initialize(config, attrs = {})
      super(config, attrs)
      @coefficient = config.network_affinity_coefficient
    end

    # Computes and returns NA(u, p), setting +value+. Must be implemented by subclasses.
    def compute(u, p)
      raise "Not implemented"
    end
  end
end

require 'rubicon/models/follow_rank/facebook'
