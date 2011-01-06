require 'sinatra/base'
require 'mongoid'
require 'haml'
require 'exceptional'

module STracker
  class SinatraTracker < Sinatra::Base
    
    use Rack::Exceptional, ENV["EXCEPTIONAL_API_KEY"] if ENV["HEROKU"]
    
    set :root, File.dirname(__FILE__)
    set :show_exceptions, true if development?

    configure do  
      $rootdir = options.root
      $environment = options.environment.to_s
    
      require File.join($rootdir, "lib/tracker")
      
      TRACKER = Tracker.new
    end

    configure :production do
      require 'newrelic_rpm' if ENV['HEROKU']
    end

    before do
      if ["/scrape", "/announce"].include? request.env['REQUEST_PATH']
        content_type 'text/plain'
        params.delete :splat
        params.merge!({"ip" => @env['REMOTE_ADDR']}) if not params.has_key? "ip"
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