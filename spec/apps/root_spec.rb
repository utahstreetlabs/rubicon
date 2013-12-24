require 'spec_helper'
require 'rack/test'
require 'rubicon/apps/root'

describe Rubicon::RootApp do
  include Rack::Test::Methods

  def app
    Rubicon::RootApp
  end

  context "GET /" do
    it "shows name and version" do
      get '/'
      last_response.body.should =~ /Rubicon v#{Rubicon::VERSION}/
    end
  end

  context "DELETE /" do
    context "succeeds" do
      it "returning 204" do
        delete '/'
        last_response.status.should == 204
      end
    end
  end
end
