require 'dino/base'
require 'dino/mongoid'
require 'rubicon/models/untargeted_invite'

module Rubicon
  module People
    class InviteApp < Dino::Base
      include Dino::MongoidApp

      # Returns a person's untargeted invite
      get '/people/:id/invite' do
        do_get do
          logger.debug("Finding untargeted invite for person #{params[:id]}")
          UntargetedInvite.find_or_create_by(person_id: params[:id])
        end
      end

      # Deletes a person's untargeted invite
      delete '/people/:id/invite' do
        do_delete do
          logger.debug("Deleting untargeted invite for person #{params[:id]}")
          UntargetedInvite.destroy_all(person_id: params[:id])
        end
      end
    end
  end
end
