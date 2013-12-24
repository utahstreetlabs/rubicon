require 'rubygems'
require 'bundler'
require 'yaml'

# Bundler >= 1.0.10 uses Psych YAML, which is broken, so fix that.
# https://github.com/carlhuda/bundler/issues/1038
YAML::ENGINE.yamler = 'syck'

Bundler.require

$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

ENV['RACK_ENV'] ||= 'development'

class Rubicon < Thor
  CONFIG = File.join('config', 'mongoid.yml')

  desc "rebuild_from_staging", "rebuilds the development database from staging"
  def rebuild_from_staging
    dev = config['development']
    st = config['staging']
    run_command(%Q/mongo #{dev['database']} --eval "db.runCommand('dropDatabase')"/)
    run_command(%Q/mongo #{dev['database']} --eval "db.copyDatabase('#{st['database']}', '#{dev['database']}', '#{st['host']}')"/)
  end

  desc 'load_fb_data INPUT', 'loads Facebook data dumped as YAML'
  def load_fb_data(input)
    load_mongoid
    require 'rubicon/models/profile'
    profile_idx = {}
    friends_idx = {}
    File.open(input) do |file|
      YAML.load_documents(file) do |data|
        profile_idx[data['id']] = load_fb_profile(data).id
      end
    end
    follows_count = 0
    File.open(input) do |file|
      YAML.load_documents(file) do |data|
        load_fb_friends(profile_idx[data['id']], profile_idx, data['friends'])
        follows_count += data['friends'].size
      end
    end
    say_ok "Loaded #{profile_idx.size} profiles and #{follows_count} follows from #{input}"
  end

  desc 'update_scope NETWORK SCOPE', "updates scope (permissions) for network by uid"
  method_option :uids, :type => :array, :default => [], :required => true, :aliases => "-i"
  def update_scope(network, scope)
    load_mongoid
    require 'rubicon/models/profile'
    options[:uids].each do |uid|
      profile = Profile.find_existing_profile_by_uid(uid, network)
      if profile
        say_trace "Found existing profile #{uid}"
        if profile.connected?
          profile.scope = scope
          profile.save!
          say_ok "Saved profile #{profile.uid} (#{profile.name})"
        end
      end
    end
  end

  desc 'correct_twitter_urls', "Corrects twitter profile URLs to point to user's profile on Twitter"
  def correct_twitter_urls
    load_mongoid
    require 'rubicon/models/profile'
    Profile.where(network: :twitter).each do |profile|
      correct_url = "https://twitter.com/#{profile.username}"
      unless profile.profile_url == correct_url
        say_trace "Correcting #{profile.profile_url} for #{profile.username} to #{correct_url}"
        profile.update_attribute(:profile_url, correct_url)
      end
    end
  end

  desc 'dump_invites_to_inviter_person_ids', "dumps a list of invite ids and inviter person ids"
  def dump_invites_to_inviter_person_ids
    load_mongoid
    require 'rubicon/models/invite'
    require 'rubicon/models/untargeted_invite'
    profiles = Profile.where(:invites.ne => nil)
    inviters = Profile.any_in(_id: profiles.map(&:invites).flatten.map(&:inviter_id)).group_by(&:id)
    profiles.each do |profile|
      profile_id = profile.id
      person_id = profile.person_id
      profile.invites.each do |invite|
        inviter = inviters[invite.inviter_id].first
        puts "#{invite.id},#{inviter.person_id}"
      end
    end
    UntargetedInvite.all.each do |invite|
        puts "#{invite.id},#{invite.person_id}"
    end
  end

protected
  def load_mongoid
    Mongoid.load!(CONFIG)
    Mongoid.logger = Logger.new(File.join('log', "#{ENV['RACK_ENV']}.log"))
  end

  def mysql2mongo_timestamp(value)
    # subtract 7 hours from each date to convert from America/Los_Angeles to GMT
    DateTime.parse(value).ago(60*60*7)
  end

  def load_fb_profile(data)
    uid = data['fbid']
    db_id = data['id']
    profile = Profile.find_existing_profile_by_uid(uid, :facebook) || Profile.new
    attrs = {
      network: :facebook,
      uid: uid,
      person_id: data['person_id'],
      token: data['token'],
      name: data['name'],
      first_name: data['firstname'],
      last_name: data['lastname'],
      email: data['email'],
      profile_url: data['link'],
      scope: data['scope'],
      created_at: data['created_at'],
      updated_at: data['updated_at'],
    }
    profile.attributes = attrs
    if profile.changed?
      profile.save!(validate: false)
      say_trace "Saved profile #{profile.uid} (#{profile.name})"
    else
      say_trace "Profile #{profile.uid} (#{profile.name}) not updated"
    end
    profile
  end

  def load_fb_friends(profile_id, profile_idx, friend_datas)
    profile = Profile.find(profile_id)
    # load the follows into memory so we don't query mongo for every friend
    follows = profile.follows.to_a
    friend_datas.each do |friend_data|
      follower = Profile.find(profile_idx[friend_data['id']])
      follow = follows.detect {|f| f.follower_id == follower.id} || profile.follows.build(follower_id: follower.id)
      attrs = {
        created_at: friend_data['created_at'],
        updated_at: friend_data['updated_at'],
      }
      follow.attributes = attrs
      if follow.changed?
        follow.save!(validate: false)
        say_trace "Saved follow from #{follower.uid} (#{follower.name}) to #{profile.uid} (#{profile.name})"
      else
        say_trace "Follow from #{follower.uid} (#{follower.name}) to #{profile.uid} (#{profile.name}) not updated"
      end
    end
  end

  def config
    @config ||= YAML.load_file(CONFIG)
  end

  def run_command(command)
    say_status :run, command
    IO.popen("#{command} 2>&1") do |f|
      while line = f.gets do
        puts line
      end
    end
  end

  def say_ok(msg)
    say_status :OK, msg, :green
  end

  def say_trace(msg)
    say_status :TRACE, msg, :blue
  end

  def say_error(msg)
    say_status :ERROR, msg, :red
  end
end
