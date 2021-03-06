require 'sinatra/base'
require 'mongoid'
require 'haml'
require 'exceptional' if ENV['HEROKU']

module STracker
  class SinatraTracker < Sinatra::Base
    
    set :root, File.dirname(__FILE__)
    set :show_exceptions, true if development?
    set :static, false
    enable :logging, :raise_errors

    configure do
      $rootdir = settings.root
      $environment = settings.environment.to_s
    
      require File.join($rootdir, "lib", "tracker")
      
      TRACKER = Tracker.new
    end

    configure :production do
      require 'newrelic_rpm' if ENV['HEROKU']
      use Rack::Exceptional, ENV["EXCEPTIONAL_API_KEY"] if ENV["HEROKU"]
    end

    before do
      @env['HTTP_X_REAL_IP'] ||= @env['REMOTE_ADDR']
            
      if ["/scrape", "/announce"].include? request.path
        content_type 'text/plain'
        params.delete :splat
        params.merge!("ip" => @env['HTTP_X_REAL_IP']) if not params.has_key? "ip"
      end
    end

    get '/announce' do
      TRACKER.announce(params)
    end

    get '/scrape' do
      TRACKER.scrape(params)
    end

    get '/status' do
      @status_hash = TRACKER.status
      haml :status
    end

    get '/favicon.ico' do; end
  end
end