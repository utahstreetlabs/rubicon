require 'spec_helper'
require 'rubicon/models/follow_rank'

describe Rubicon::FollowRank do
  class HogwartsFollowRank < Rubicon::FollowRank
    def self.build_network_affinity(config, attrs = {})
      HogwartsNetworkAffinity.new(config, attrs)
    end

    def self.network
      :hogwarts
    end
  end

  class HogwartsNetworkAffinity < Rubicon::FollowRankNetworkAffinity
  end

  let(:scv) { 5 }
  let(:scc) { 4 }
  let(:nav) { 3 }
  let(:nac) { 2 }
  let(:v)   { scv*scc + nav*nac}

  before do
    Rubicon.configuration.follow_rank.hogwarts = OpenStruct.new(
      shared_connections_coefficient: scc,
      network_affinity_coefficient: nac
    )
  end

  subject do
    HogwartsFollowRank.new('value' => v, 'shared_connections' => {'value' => scv},
      'network_affinity' => {'value' => nav})
  end

  describe "#initialize" do
    it "initializes its components" do
      subject.shared_connections.should be_a(Rubicon::FollowRankSharedConnections)
      subject.shared_connections.value.should == scv
      subject.network_affinity.should be_a(HogwartsNetworkAffinity)
      subject.network_affinity.value.should == nav
    end
  end

  describe "#compute" do
    let(:u) { stub('u') }
    let(:p) { stub('p') }

    it "applies the FR formula" do
      subject.shared_connections.expects(:compute).with(u, p).returns(scc)
      subject.network_affinity.expects(:compute).with(u, p).returns(scv)
      subject.compute(u, p).should == v
    end
  end

  describe "#config" do
    it "returns the appropriate config object" do
      subject.config.should == Rubicon.configuration.follow_rank.hogwarts
    end
  end

  describe "#to_params" do
    subject { HogwartsFollowRank.new('value' => v) }

    it "returns a params hash" do
      scp = stub('scp')
      nap = stub('nap')
      subject.shared_connections.expects(:to_params).returns(scp)
      subject.network_affinity.expects(:to_params).returns(nap)
      subject.to_params.should == {value: v, shared_connections_attributes: scp, network_affinity_attributes: nap}
    end
  end
end
