require 'bencode'
require 'uri'
require 'yaml'
require 'erb'
require File.join($rootdir, "lib", "clogger")
require File.join($rootdir, "lib", "peer")
require File.join($rootdir, "lib", "torrent")
require File.join($rootdir, "lib", "request")

module STracker
  class TrackerException < Exception; end
  
  class Tracker
    attr_reader :tracker_id, :announce_interval, :timeout_interval, :min_announce_interval, :allow_unregistered_torrents, :allow_noncompact, :full_scrape
    
    if $environment == "test"
      attr_writer :tracker_id, :announce_interval, :timeout_interval, :min_announce_interval, :allow_unregistered_torrents, :allow_noncompact, :full_scrape
    end
    
    def initialize
      config = YAML.load_file File.join($rootdir, "config/tracker.yaml")
      config[$environment].each { |key, value| instance_variable_set("@#{key}", value) }
      @mongo_uri = ERB.new(@mongo_uri).result
      
      @logger = CustomLogger.new(File.join($rootdir, "log/tracker.log"), 2, 1024 * 1024 * 2)
      
      init_mongo
    end
    
    def announce(req)
      begin
        request = Request.new(req)
        #@logger.info "Request from #{request.ip} with torrent #{request.info_hash}."        
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
        
        torrent.update_torrent(request, @min_announce_interval)
        
        zombies = torrent.clear_zombies(Time.now - @timeout_interval)
        @logger.info "Torrent had #{zombies} in it, removed them." if zombies > 0
        
        peers = torrent.get_peers(request.numwant, request.compact)
        @logger.info "Sent #{peers.count} peers to #{request.ip} for torrent #{request.info_hash}."
        
        {"complete" => torrent.seeders,
         "incomplete" => torrent.leechers,
         "interval" => @announce_interval,
         "tracker id" => @tracker_id,
         "min interval" => @min_announce_interval,
         "peers" => peers,
         "downloaded" => torrent.completed}.bencode
        
      rescue TrackerException => ex
        @logger.info "Request from #{req["ip"]} failed. Reason: #{ex.message}"
        return send_error(ex.message)
      end
    end
    
    def scrape(params)
      if params.keys.include? "info_hash"
        torrents = [Torrent.find(STracker::Tracker.bin2hex(params["info_hash"]))]
      elsif @full_scrape
        torrents = Torrent.only(:seeders, :leechers, :completed)
      else
        return send_error("Full scrape is not permitted!")
      end
      
      out = {}
      torrents.each do |torrent|
        out.merge!({
          STracker::Tracker.hex2bin(torrent.id) => {
            "complete" => torrent.seeders,
            "incomplete" => torrent.leechers,
            "downloaded" => torrent.completed
          }
        })
      end
      
      if not out.empty?
        {"files" => out}.bencode
      else
        send_error("The tracker is empty!")
      end
    end
    
    def status
      {:torrents => Torrent.all}
    end
    
    def self.bin2hex(bin)
      (bin.unpack "H*").first
    end
    
    def self.hex2bin(hex)
      [hex].pack "H*"
    end
    
    private
    
    def send_error(msg)
      {"failure reason" => msg}.bencode
    end
    
    def init_mongo      
      Mongoid.configure do |config|
        logger = Logger.new(File.join($rootdir, "log/mongoid.log"), 2, 1024 * 1024 * 2)
        config.master = Mongo::Connection.from_uri(@mongo_uri, :logger => logger).db(URI.parse(@mongo_uri).path.gsub(/^\//, ''))
      end
    end
  end
end