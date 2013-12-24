require 'rubygems'
require 'bundler'
require 'yaml'

# Bundler >= 1.0.10 uses Psych YAML, which is broken, so fix that.
# https://github.com/carlhuda/bundler/issues/1038
YAML::ENGINE.yamler = 'syck'

Bundler.require

$LOAD_PATH << File.join(File.dirname(__FILE__), 'lib')

require 'dino/cascade'
require 'rubicon/apps/invites'
require 'rubicon/apps/people/invite'
require 'rubicon/apps/profiles'
require 'rubicon/apps/root'

use LogWeasel::Middleware

apps = []
apps << Rubicon::RootApp
apps << Rubicon::InvitesApp
apps << Rubicon::People::InviteApp
apps << Rubicon::ProfilesApp

run Dino::Cascade.new(*apps)
