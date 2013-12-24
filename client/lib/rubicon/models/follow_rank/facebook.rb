require 'rubicon/models/follow_rank'

module Rubicon
  class FacebookFollowRank < FollowRank
    def self.build_network_affinity(config, attrs)
      FacebookNetworkAffinity.new(config, attrs)
    end

    def self.network
      :facebook
    end

    def self._type
      :FacebookFollowRank
    end
  end

  class FacebookNetworkAffinity < FollowRankNetworkAffinity
    attr_accessor :photo_tags, :photo_annotations, :status_annotations

    def initialize(config, attrs = {})
      super_attrs = attrs.reject do |key, value|
        [:photo_tags, :photo_annotations, :status_annotations].include?(key.to_sym)
      end
      super(config, super_attrs)
      @photo_tags = FacebookPhotoTags.new(config, attrs.fetch('photo_tags', {}))
      @photo_annotations = FacebookPhotoAnnotations.new(config, attrs.fetch('photo_annotations', {}))
      @status_annotations = FacebookStatusAnnotations.new(config, attrs.fetch('status_annotations', {}))
    end

    # Computes and returns NA(u, p), setting +value+.
    def compute(u, p)
      self.value = photo_tags.compute(u, p) * photo_tags.coefficient +
        photo_annotations.compute(u, p) * photo_annotations.coefficient +
          status_annotations.compute(u, p) * status_annotations.coefficient
    end

    def to_params
      [:photo_tags, :photo_annotations, :status_annotations].inject(super) do |m, key|
        m.merge!("#{key}_attributes".to_sym => send(key).to_params)
      end
    end
  end

  class FacebookPhotoTags < FollowRankMetadata
    def initialize(config, attrs = {})
      super(config, attrs)
      @coefficient = config.photo_tags_coefficient
    end

    # Computes and returns PT(u, p), setting +value+.
    def compute(u, p)
      self.value = u.photos.count do |photo|
        photo.tags.fetch('data', []).map {|t| t['id']}.include?(p.uid)
      end
      self.value = 0 unless value >= config.photo_tags_minimum
#      logger.debug("Photo tags for #{u.id} and #{p.id}: #{value}")
      value
    end
  end

  class FacebookPhotoAnnotations < FollowRankMetadata
    def initialize(config, attrs = {})
      super(config, attrs)
      @coefficient = config.photo_annotations_coefficient
    end

    # Computes and returns PA(u, p), setting +value+.
    def compute(u, p)
      self.value = u.photos.inject(0) do |sum, photo|
        if self.class.in_time_window(photo.created_time, config.photo_annotations_window)
          sum += photo.likes.fetch('data', []).count {|l| l['id'] == p.uid} if photo.likes
          sum += photo.comments.fetch('data', []).count {|c| c.fetch('from', {})['id'] == p.uid} if photo.comments
        end
        sum
      end
#      logger.debug("Photo annotations for #{u.id} and #{p.id}: #{value}")
      value
    end
  end

  class FacebookStatusAnnotations < FollowRankMetadata
    def initialize(config, attrs = {})
      super(config, attrs)
      @coefficient = config.status_annotations_coefficient
    end

    # Computes and returns SA(u, p), setting +value+.
    def compute(u, p)
      self.value = u.statuses.inject(0) do |sum, status|
        if self.class.in_time_window(status.created_time, config.status_annotations_window)
          sum += status.likes.fetch('data', []).count {|l| l['id'] == p.uid} if status.likes
          sum += status.comments.fetch('data', []).count {|c| c.fetch('from', {})['id'] == p.uid} if status.comments
        end
        sum
      end
#      logger.debug("Status annotations for #{u.id} and #{p.id}: #{value}")
      value
    end
  end
end
