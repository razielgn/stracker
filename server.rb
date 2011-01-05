require 'sinatra'
require 'mongoid'
require 'haml'
require 'redis'

require File.join(settings.root, "lib/tracker")
include STracker

set :run, true

configure do
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  
  SinatraTracker = Tracker.new
end

configure :production do
  require 'rpm_contrib' if ENV['HEROKU']
end

before do
  content_type 'text/plain'
  params.delete :splat
end

get '/announce' do
  if !params.has_key?("ip")
    params.merge!({"ip" => @env['REMOTE_ADDR']})
  end
  
  SinatraTracker.announce(params)
end

get '/scrape' do
  SinatraTracker.scrape(params)
end

get '/status' do
  content_type "text/html"
  @torrents = SinatraTracker.status
  haml :status
end

get '/favicon.ico' do; end