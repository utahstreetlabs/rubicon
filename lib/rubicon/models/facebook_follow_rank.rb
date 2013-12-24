require 'rubicon/models/follow_rank'

class FacebookFollowRank < FollowRank
  embeds_one :network_affinity, class_name: 'FacebookFollowRankNetworkAffinity'
  accepts_nested_attributes_for :network_affinity
end

class FacebookFollowRankNetworkAffinity < FollowRankMetadata
  embeds_one :photo_tags, class_name: 'FollowRankMetadata'
  accepts_nested_attributes_for :photo_tags

  embeds_one :photo_annotations, class_name: 'FollowRankMetadata'
  accepts_nested_attributes_for :photo_annotations

  embeds_one :status_annotations, class_name: 'FollowRankMetadata'
  accepts_nested_attributes_for :status_annotations
end
