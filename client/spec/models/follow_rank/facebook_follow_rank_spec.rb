require 'spec_helper'
require 'rubicon/models/follow_rank'
require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/date/calculations'

describe Rubicon::FacebookFollowRank do
  describe "#build_network_affinity" do
    let(:config) { Rubicon.configuration.follow_rank.facebook }

    it "should return a FacebookNetworkAffinity" do
      Rubicon::FacebookFollowRank.build_network_affinity(config, {}).should be_a(Rubicon::FacebookNetworkAffinity)
    end
  end
end

describe Rubicon::FacebookNetworkAffinity do
  let(:nac) { Rubicon.configuration.follow_rank.facebook.network_affinity_coefficient }
  let(:ptv) { 12 }
  let(:ptc) { Rubicon.configuration.follow_rank.facebook.photo_tags_coefficient }
  let(:pav) { 18 }
  let(:pac) { Rubicon.configuration.follow_rank.facebook.photo_annotations_coefficient }
  let(:sav) { 26 }
  let(:sac) { Rubicon.configuration.follow_rank.facebook.status_annotations_coefficient }
  let(:v) { ptv*ptc + pav*pac + sav*sac }

  subject do
    Rubicon::FacebookNetworkAffinity.new(Rubicon.configuration.follow_rank.facebook, 'value' => v,
      'photo_tags' => {'value' => ptv}, 'photo_annotations' => {'value' => pav},
      'status_annotations' => {'value' => sav})
  end

  describe "#initialize" do
    it "initializes its components" do
      subject.photo_tags.should be_a(Rubicon::FacebookPhotoTags)
      subject.photo_tags.value.should == ptv
      subject.photo_annotations.should be_a(Rubicon::FacebookPhotoAnnotations)
      subject.photo_annotations.value.should == pav
      subject.status_annotations.should be_a(Rubicon::FacebookStatusAnnotations)
      subject.status_annotations.value.should == sav
    end
  end

  describe "#compute" do
    let(:u) { stub('u') }
    let(:p) { stub('p') }

    it "applies the NA formula" do
      subject.photo_tags.expects(:compute).with(u, p).returns(ptv)
      subject.photo_annotations.expects(:compute).with(u, p).returns(pav)
      subject.status_annotations.expects(:compute).with(u, p).returns(sav)
      subject.compute(u, p).should == v
    end
  end

  describe "#to_params" do
    it "returns a params hash" do
      pta = stub('pta')
      paa = stub('paa')
      saa = stub('saa')
      subject.photo_tags.expects(:to_params).returns(pta)
      subject.photo_annotations.expects(:to_params).returns(paa)
      subject.status_annotations.expects(:to_params).returns(saa)
      subject.to_params.should == {value: v, coefficient: nac, photo_tags_attributes: pta,
        photo_annotations_attributes: paa, status_annotations_attributes: saa}
    end
  end
end

describe Rubicon::FacebookPhotoTags do
  let(:ptv) { 12 }
  let(:ptc) { Rubicon.configuration.follow_rank.facebook.photo_tags_coefficient }
  let(:v) { ptv*ptc }

  subject do
    Rubicon::FacebookPhotoTags.new(Rubicon.configuration.follow_rank.facebook, 'value' => v)
  end

  describe "#initialize" do
    it "initializes its components" do
      subject.coefficient.should == ptc
    end
  end

  describe "#compute" do
    let(:u) { stub('u') }
    let(:p) { stub('p', uid: '12345') }
    let(:photo1) { stub('photo1', tags: {'data' => [{'id' => p.uid}]}) }
    let(:photo2) { stub('photo2', tags: {'data' => [{'id' => p.uid}]}) }

    context "when there are at least the minimum number of photo tags" do
      before { u.expects(:photos).returns([photo1, photo2]) }

      it "applies the PT formula" do
        subject.compute(u, p).should == 2*ptc
      end
    end

    context "when there are fewer than the minimum number of photo tags" do
      before { u.expects(:photos).returns([photo1]) }

      it "applies the PT formula" do
        subject.compute(u, p).should == 0
      end
    end
  end

  describe "#to_params" do
    it "returns a params hash" do
      subject.to_params.should == {value: v, coefficient: ptc}
    end
  end
end

describe Rubicon::FacebookPhotoAnnotations do
  let(:pav) { 12 }
  let(:pac) { Rubicon.configuration.follow_rank.facebook.photo_annotations_coefficient }
  let(:v) { pav*pac }

  subject do
    Rubicon::FacebookPhotoAnnotations.new(Rubicon.configuration.follow_rank.facebook, 'value' => v)
  end

  describe "#initialize" do
    it "initializes its components" do
      subject.coefficient.should == pac
    end
  end

  describe "#compute" do
    let(:u) { stub('u', photos: [photo]) }
    let(:p) { stub('p', uid: '12345') }
    let(:photo) { stub('photo', likes: {'data' => [{'id' => p.uid}]}, comments: {'data' => []}) }

    context "when a photo was created within the configured window" do
      before { photo.expects(:created_time).returns(1.day.ago.to_s) }

      it "applies the PT formula" do
        subject.compute(u, p).should == 1*pac
      end
    end

    context "when no photos were created within the configured window" do
      before { photo.expects(:created_time).returns(365.days.ago.to_s) }

      it "applies the PT formula" do
        subject.compute(u, p).should == 0
      end
    end
  end

  describe "#to_params" do
    it "returns a params hash" do
      subject.to_params.should == {value: v, coefficient: pac}
    end
  end
end

describe Rubicon::FacebookStatusAnnotations do
  let(:sav) { 12 }
  let(:sac) { Rubicon.configuration.follow_rank.facebook.status_annotations_coefficient }
  let(:v) { sav*sac }

  subject do
    Rubicon::FacebookStatusAnnotations.new(Rubicon.configuration.follow_rank.facebook, 'value' => v)
  end

  describe "#initialize" do
    it "initializes its components" do
      subject.coefficient.should == sac
    end
  end

  describe "#compute" do
    let(:u) { stub('u', statuses: [status]) }
    let(:p) { stub('p', uid: '12345') }
    let(:status) { stub('status', likes: {'data' => [{'id' => p.uid}]}, comments: {'data' => []}) }

    context "when a status was created within the configured window" do
      before { status.expects(:created_time).returns(1.day.ago.to_s) }

      it "applies the PT formula" do
        subject.compute(u, p).should == 1*sac
      end
    end

    context "when no statuss were created within the configured window" do
      before { status.expects(:created_time).returns(365.days.ago.to_s) }

      it "applies the PT formula" do
        subject.compute(u, p).should == 0
      end
    end
  end

  describe "#to_params" do
    it "returns a params hash" do
      subject.to_params.should == {value: v, coefficient: sac}
    end
  end
end
