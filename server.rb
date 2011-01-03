require 'sinatra'
require 'mongoid'
require 'haml'
require File.join(settings.root, "lib/tracker")

include STracker

set :run, true

configure do
  Tracker = Tracker.new
end

configure :production do
  require 'newrelic_rpm' if ENV['HEROKU']
end

before do
  content_type 'text/plain'
  params.delete :splat
end

get '/announce' do
  if !params.has_key?("ip")
    params.merge!({"ip" => @env['REMOTE_ADDR']})
  end
  
  Tracker.announce(params)
end

get '/scrape' do
  Tracker.scrape(params)
end

get '/status' do
  content_type "text/html"
  @torrents = Tracker.status
  haml :status
end

get '/favicon.ico' do; end