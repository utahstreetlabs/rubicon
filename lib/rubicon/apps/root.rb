require 'dino/base'
require 'dino/mongoid'
require 'rubicon/version'

module Rubicon
  class RootApp < Dino::Base
    set :root, File.join(File.dirname(__FILE__), '..', '..', '..')
    set :version_string, "Rubicon v#{Rubicon::VERSION}"
    set :mongoid_config, File.expand_path(File.join(settings.root, 'config', 'mongoid.yml'))

    logger.info("Starting #{settings.version_string}")

    include Dino::MongoidApp
    load_mongoid(settings.mongoid_config)

    get '/' do
      settings.version_string
    end

    delete '/' do
      do_delete do
        logger.debug("Nuking all data!")
        Follow.delete_all
        Profile.delete_all
      end
    end
  end
end
