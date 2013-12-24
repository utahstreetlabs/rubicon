# -*- encoding: utf-8 -*-
require File.expand_path('../lib/rubicon/version', __FILE__)

Gem::Specification.new do |s|
  s.name = 'rubicon'
  s.version = Rubicon::VERSION.dup
  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.6") if s.respond_to? :required_rubygems_version=
  s.required_ruby_version = Gem::Requirement.new(">= 1.9.2")
  s.authors = ['Brian Moseley']
  s.description = 'Rubicon external network data client library'
  s.email = ['bcm@copious.com']
  s.homepage = 'http://github.com/utahstreetlabs/rubicon'
  s.rdoc_options = ['--charset=UTF-8']
  s.summary = "A client library for the Rubicon external network data service"
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.files = `git ls-files -- lib/*`.split("\n")
  s.test_files = `git ls-files -- {test,spec,features}/*`.split("\n")

  s.add_development_dependency('rake')
  s.add_development_dependency('mocha', '~> 0.10.5')
  s.add_development_dependency('rspec')
  s.add_development_dependency('gemfury', '>= 0.4.9')
  s.add_development_dependency('timecop', '~> 0.3.5')
  s.add_runtime_dependency('ladon', '~> 4.0')
  s.add_runtime_dependency('twitter', '2.2.0')
  s.add_runtime_dependency('tumblife', '0.3.1')
  s.add_runtime_dependency('instagram', '0.8.5.copious')
  s.add_runtime_dependency('mogli', '0.0.36.6.copious')
  s.add_runtime_dependency('faraday')
  s.add_runtime_dependency('flyingdog', '>= 1.0.0')
  s.add_runtime_dependency('redhook', '>= 1.0.0')
  s.add_runtime_dependency('typhoeus', '>= 0.2.4.2.copious')
  s.add_runtime_dependency('builder', '3.0.4')
  s.add_runtime_dependency('activesupport', '~> 3.1.11')
end
