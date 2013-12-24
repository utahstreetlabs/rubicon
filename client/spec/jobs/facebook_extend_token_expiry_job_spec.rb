require 'spec_helper'
require 'rubicon/jobs/facebook_extend_token_expiry_job'

describe Rubicon::Jobs::FacebookExtendTokenExpiry do
  class Person; end # stub brooklyn class

  describe '#perform' do
    let(:profile) { stub('profile', uid: 1) }
    let(:person_id) { 2 }

    context "when exchanging auth tokens by person id" do
      context "for a connected facebook profile" do
        before do
          profile.stubs(:connected?).returns(true)
          profile.stubs(:network).returns(:facebook)
        end

        it "should exchange tokens" do
          Rubicon::Profile.expects(:find_for_person_and_network).with(person_id, profile.network).
            returns(profile)
          profile.expects(:extend_token_expiry)
          Rubicon::Jobs::FacebookExtendTokenExpiry.perform(person_id)
        end
      end

      context "for a person without a facebook profile" do
        it "should not exchange tokens" do
          Rubicon::Profile.expects(:find_for_person_and_network).with(person_id, :facebook).returns(nil)
          profile.expects(:extend_token_expiry).never
          Rubicon::Jobs::FacebookExtendTokenExpiry.perform(person_id)
        end
      end

      context "for a disconnected profile" do
        before do
          profile.stubs(:connected?).returns(false)
          profile.stubs(:network).returns(:facebook)
        end

        it "should not exchange tokens" do
          Rubicon::Profile.expects(:find_for_person_and_network).with(person_id, profile.network).
            returns(profile)
          profile.expects(:extend_token_expiry).never
          Rubicon::Jobs::FacebookExtendTokenExpiry.perform(person_id)
        end
      end
    end
  end
end
