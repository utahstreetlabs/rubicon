require 'factory_girl'

FactoryGirl.define do
  factory :profile do
    sequence(:person_id) {|n| n}
    network 'twitter'
    type nil
    secure false
    sequence(:uid) {|n| "uid-#{n}"}
  end

  factory :connected_profile, parent: :profile do
    token 'deadbeef'
    secret 'cafebebe'
  end

  factory :follow do
    profile
    follower_id '4e775ad83cbbfc05bf000001'
  end

  factory :invite do
    profile
    inviter_id '4e775ad83cbbfc05bf000001'
  end

  factory :untargeted_invite do
    sequence(:person_id) {|n| n}
  end
end
