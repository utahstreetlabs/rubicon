load 'deploy'

require 'bundler/capistrano'

set :bundle_flags, "--deployment"
set :stages, %w(demo staging production)
set :default_stage, "staging"
require 'capistrano/ext/multistage'

set :user, 'utah'
set :application, 'rubicon'
# domain is set in config/deploy/{stage}.rb

# Mongo indexes
set :index_mongo, false

# file paths
set :repository, "git@github.com:utahstreetlabs/rubicon.git"
set(:deploy_to) { "/home/#{user}/#{application}" }

# one server plays all roles
role :app do
  fetch(:domain)
end

role :primary do
  fetch(:primary_host)
end

set(:rails_env) { stage }
set :deploy_via, :remote_cache
set :scm, 'git'
set :scm_verbose, true
set(:branch) do
  case stage
  when :production then "production"
  else "staging"
  end
end
set :use_sudo, false

after "deploy:restart", "deploy:reindex"
after "deploy", "deploy:cleanup"

namespace :deploy do
  task :start, :roles => :app, :except => { :no_release => true } do
    run "#{sudo} start rubicon"
  end

  task :stop, :roles => :app, :except => { :no_release => true } do
    run "#{sudo} stop rubicon"
  end

  task :restart, :roles => :app, :except => { :no_release => true } do
    stop
    start
  end

  task :reindex, :roles => :primary do
    run "cd #{latest_release} && RACK_ENV=#{stage} bundle exec rake mongo:create_indexes" if index_mongo
  end
end
