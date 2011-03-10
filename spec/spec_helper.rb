require 'cover_me'

require File.join(File.dirname(__FILE__), '..', 'server.rb')

require 'sinatra'
require 'rack/test'
require 'spec'
require 'spec/autorun'
require 'spec/interop/test'

# set test environment
set :environment, :test
set :run, false
set :raise_errors, true
set :logging, false

def fake_torrents
  @fakes ||= open(File.join(File.dirname(__FILE__), 'fixtures', 'fake_hashes.txt')).readlines.map {|c| c.strip}
  return @fakes
end

def fill_tracker
  fake_torrents.each {|hash| Torrent.create! :_id => hash}
end

def random_hash
  fake_torrents[srand % fake_torrents.count]
end