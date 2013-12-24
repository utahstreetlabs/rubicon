require 'spec_helper'
require 'rubicon/resource/root'

describe Rubicon::Root do
  context "#nuke" do
    it "clears everything" do
      Rubicon::Root.expects(:fire_delete).with('/').once
      Rubicon::Root.nuke
    end
  end
end
