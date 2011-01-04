require 'bencode'
require 'uri'
require 'yaml'
require 'erb'
require File.join(settings.root, "lib/clogger")
require File.join(settings.root, "lib/torrent")
require File.join(settings.root, "lib/peer")
require File.join(settings.root, "lib/request")

module STracker
  class TrackerException < Exception; end
  
  class Tracker
    attr_reader :tracker_id, :announce_interval, :timeout_interval, :min_announce_interval, :allow_unregistered_torrents, :allow_noncompact
  
    def initialize
      config = YAML.load_file File.join(settings.root, "config/tracker.yaml")
      config[settings.environment.to_s].each { |key, value| instance_variable_set("@#{key}", value) }
      @mongo_uri = ERB.new(@mongo_uri).result
      
      @logger = CustomLogger.new(File.join(settings.root, "log/tracker.log"), 2, 1024 * 1024 * 2)
      
      init_mongo
    end
    
    def announce(req)
      begin
        request = Request.new(req)
        @logger.info "Request from #{request.ip} with torrent #{request.info_hash}."        
        torrent = Torrent.find(:one, :conditions => {:_id => request.info_hash}).first
        
        if torrent.nil?
          if @allow_unregistered_torrents
            @logger.info "Torrent #{request.info_hash} was not in list, added."
            torrent = Torrent.new(:_id => request.info_hash)
          else
            raise TrackerException, "Torrent not in list!"
          end
        end
        
        if @allow_non_compact && !request.compact
          raise TrackerException, "Non-compact response is not supported!"
        end
        
        torrent.update_torrent(request)
        
        zombies = torrent.clear_zombies(Time.now - @timeout_interval)
        @logger.info "Torrent had #{zombies} in it, removed them."
        
        peers = torrent.get_peers(request.numwant, request.compact)
        @logger.info "Sent #{peers.count} to #{request.ip} for torrent #{request.info_hash}."
        
        {"complete" => torrent.seeders,
         "incomplete" => torrent.leechers,
         "interval" => @announce_interval,
         "tracker id" => @tracker_id,
         "min interval" => @min_announce_interval,
         "peers" => peers,
         "downloaded" => torrent.completed}.bencode
        
      rescue TrackerException => ex
        @logger.info "Request from #{req["ip"]} failed. Reason: #{ex.message}"
        {"failure reason" => ex.message}.bencode
        return
      end
    end
    
    def scrape(params)
      if params.keys.include? "info_hash"
        torrents = [Torrent.find((params["info_hash"].unpack "H*").first)]
      else
        torrents = Torrent.all
      end
      
      lolz = {}
      
      torrents.each do |torrent|
        lolz.merge!({
          [torrent.id].pack("H*") => {
            "complete" => torrent.seeders,
            "incomplete" => torrent.leechers,
            "downloaded" => torrent.completed
          }
        })
      end
      
      {"files" => lolz}.bencode
    end
    
    def status
      Torrent.all
    end
    
    private
    
    def send_error(msg)
      {"failure reason" => msg}.bencode
    end
    
    def init_mongo      
      Mongoid.configure do |config|
        logger = Logger.new(File.join(settings.root, "log/mongoid.log"), 2, 1024 * 1024 * 2)
        config.master = Mongo::Connection.from_uri(@mongo_uri, :logger => logger).db(URI.parse(@mongo_uri).path.gsub(/^\//, ''))
      end
    end
  end
end