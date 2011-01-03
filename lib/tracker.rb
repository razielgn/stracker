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
    attr_reader :tracker_id, :announce_interval, :timeout_interval, :min_announce_interval, :allow_unregistered_torrents, :allow_noncompact, :req_counter
  
    @@req_counter = 0
  
    def initialize
      config = YAML.load_file File.join(settings.root, "config/tracker.yaml")
      config[settings.environment.to_s].each { |key, value| instance_variable_set("@#{key}", value) }
      @mongo_uri = ERB.new(@mongo_uri).result
      
      @logger = CustomLogger.new(File.join(settings.root, "log/tracker.log"), 2, 1024 * 1024 * 2)
      @id_lock = Mutex.new
      
      init_mongo
    end
    
    def announce(req)
      req_id = gen_req_id
      
      begin
        request = Request.new(req)
        @logger.info "#{req_id} - Request from #{req["ip"]} with torrent #{request.info_hash}."        
        torrent = Torrent.find(:one, :conditions => {:_id => request.info_hash}).first
        
        if torrent.nil?
          if @allow_unregistered_torrents
            @logger.info "#{req_id} - Torrent #{request.info_hash} was not in list, added."
            torrent = Torrent.create!(:_id => request.info_hash)
          else
            raise TrackerException, "Torrent not in list!"
          end
        end
        
        if @allow_non_compact && !request.compact
          raise TrackerException, "Non-compact response is not supported!"
        end
        
        torrent.update_torrent(request)
        
        zombies = torrent.clear_zombies(Time.now - @timeout_interval)
        @logger.info "#{req_id} - Torrent had #{zombies} in it, removed them."
        
        torrent.save!
        
        peers = torrent.get_peers(request.numwant, request.compact)
        @logger.info "#{req_id} - Sent #{peers.count} from torrent #{request.info_hash}."
        
        return {"complete" => torrent.seeders,
         "incomplete" => torrent.leechers,
         "interval" => @announce_interval,
         "tracker id" => @tracker_id,
         "min interval" => @min_announce_interval,
         "peers" => peers
         }.bencode
      rescue TrackerException => ex
        @logger.info "#{req_id} - Request from #{req["ip"]} failed. Reason: #{ex.message}"
        {"failure reason" => ex.message}.bencode
        return
      end
    end
    
    def scrape
    end
    
    def status
      Torrent.all
    end
    
    private
    
    def init_mongo      
      Mongoid.configure do |config|
        config.logger = Logger.new(File.join(settings.root, "log/mongoid.log"), 2, 1024 * 1024 * 2)
        config.master = Mongo::Connection.from_uri(@mongo_uri).db(URI.parse(@mongo_uri).path.gsub(/^\//, ''))
      end
    end
    
    def gen_req_id
      req_id = -1
      @id_lock.synchronize do
        req_id = @@req_counter += 1
      end
      
      req_id
    end
  end
end