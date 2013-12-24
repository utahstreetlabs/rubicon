require 'dino/base'
require 'dino/mongoid'
require 'rubicon/models'

module Rubicon
  class InvitesApp < Dino::Base
    include Dino::MongoidApp

    # Get all invites embedded in a profile
    get '/profiles/:id/invites' do
      do_get do
        logger.debug("Finding all invites for profile #{params[:id]}")
        profile = Profile.find(params[:id])
        # Only return the invites attached to existing profiles
        {invites: profile.invites.where(:inviter_id.in => Profile.where(:_id.in => profile.invites.map(&:inviter_id)).map(&:id)).entries}
      end
    end

    # Get all profiles (inviters) for invites embedded in a profile
    get '/profiles/:id/inviters' do
      do_get do
        logger.debug("Finding all inviters for profile #{params[:id]}")
        profile = Profile.find(params[:id])
        {profiles: Profile.where(:_id.in => profile.invites.map(&:inviter_id)).entries.map {|p| p.serializable_hash}}
      end
    end

    # Get a specific invite by profile (inviter) id
    get '/profiles/:id/invites/from/:inviter_id' do
      do_get do
        profile = Profile.find(params[:id])
        logger.debug("Finding inviter profile #{params[:inviter_id]} for profile #{params[:id]}")
        profile.invites.find(inviter_id: params[:inviter_id])
      end
    end

    # Create/update an invite by profile id.
    put '/profiles/:id/invites/from/:inviter_id' do
      do_put do
        profile = Profile.find(params[:id])
        logger.debug("Adding invite profile id #{params[:inviter_id]} to profile #{params[:id]}")
        profile.invited!(BSON::ObjectId.from_string(params[:inviter_id]))
      end
    end

    # Remove an invite by profile (inviter) id
    delete '/profiles/:id/invites/from/:inviter_id' do
      do_delete do
        # Throws a 404 and fails silently if no profile found
        profile = Profile.find(params[:id])
        logger.debug("Deleting invite to profile #{params[:id]} from inviter #{params[:inviter_id]}")
        profile.uninvited!(BSON::ObjectId.from_string(params[:inviter_id]))
      end
    end

    # Remove all invites for a profile
    delete '/profiles/:id/invites' do
      do_delete do
        profile = Profile.find(params[:id])
        logger.debug("Deleting all invites for profile #{params[:id]}")
        profile.invites.destroy_all
      end
    end

    # Get an untargeted invite
    get '/invites/untargeted/:id' do
      do_get do
        logger.debug("Finding untargeted invite #{params[:id]}")
        UntargetedInvite.find(params[:id])
      end
    end

    # Get a targeted invite
    get '/invites/:id' do
      do_get do
        logger.debug("Finding invite #{params[:id]}")
        invite = Invite.find_invite(BSON::ObjectId.from_string(params[:id]))
        raise Dino::NotFound unless invite
        invite.to_wire_hash
      end
    end
  end
end
