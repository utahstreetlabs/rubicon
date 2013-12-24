require 'spec_helper'
require 'rubicon/jobs/sync_base'

describe Rubicon::Jobs::Sync do
  class Person; end # stub brooklyn class

  describe '#perform' do
    let(:profile) { stub('profile', uid: 1, network: 'friendster', connected?: true) }
    let(:person_id) { 2 }
    let(:follower_person) { stub 'follower-person', id: 3}

    context "when syncing by uid" do
      it "should look up the profile by uid" do
        Person.expects(:create!).returns(follower_person)
        profile.expects(:sync).yields
        Rubicon::Profile.expects(:find_for_uid_and_network).with(profile.uid, profile.network).
          returns(profile)
        Rubicon::Jobs::Sync.perform(nil, profile.network, {'uid' => profile.uid})
      end
    end

    context "when syncing by person id" do
      it "should look up the profile by person id" do
        Person.expects(:create!).returns(follower_person)
        profile.expects(:sync).yields
        Rubicon::Profile.expects(:find_for_person_and_network).with(person_id, profile.network).
          returns(profile)
        Rubicon::Jobs::Sync.perform(person_id, profile.network)
      end
    end

    context "when syncing only profile attributes by uid" do
      it "should look up the profile by uid" do
        profile.expects(:sync_attrs)
        Rubicon::Profile.expects(:find_for_uid_and_network).with(profile.uid, profile.network).
          returns(profile)
        Rubicon::Jobs::SyncAttrs.perform(nil, profile.network, {'uid' => profile.uid})
      end
    end

    context "when syncing only profile attributes by person id" do
      it "should look up the profile by person id" do
        profile.expects(:sync_attrs)
        Rubicon::Profile.expects(:find_for_person_and_network).with(person_id, profile.network).
          returns(profile)
        Rubicon::Jobs::SyncAttrs.perform(person_id, profile.network)
      end
    end
  end
end
