%w[bencode uri yaml erb].each {|lib| require lib}
%w[clogger core_extensions peer torrent request].each {|lib| require File.join($rootdir, "lib", lib)}

module STracker
  class TrackerException < Exception; end
  
  class Tracker
    attr_reader :tracker_id, :announce_interval, :timeout_interval, :min_announce_interval, :allow_unregistered_torrents, :allow_noncompact, :full_scrape
    
    def initialize
      config = YAML.load_file File.join($rootdir, "config", "tracker.yaml")
      config[$environment].each { |key, value| instance_variable_set("@#{key}", value) }
      
      @logger = CustomLogger.new(File.join($rootdir, "log", "tracker.log"), 2, 1024 * 1024 * 2)

      @mongo_uri = ERB.new(@mongo_uri).result
      init_mongo
    end
    
    def announce(req)
      begin
        request = Request.new(req)
        
        if @allow_non_compact and not request.compact
          raise TrackerException, "Non-compact response is not supported!"
        end
        
        torrent = Torrent.find(:one, :conditions => {:_id => request.info_hash}).first
        
        if torrent.nil?
          if @allow_unregistered_torrents
            @logger.info "Torrent #{request.info_hash} was not in list, added."
            torrent = Torrent.new(:_id => request.info_hash)
          else
            raise TrackerException, "Torrent not in list!"
          end
        end
        
        torrent.update_torrent(request)
        
        return "" if request.event == "stopped"
        
        zombies = torrent.clear_zombies(Time.now - @timeout_interval)
        @logger.info "Torrent had #{zombies} in it, removed them." if zombies > 0
        
        peers = torrent.get_peers(request.numwant, request.compact)
        @logger.info "Sent #{request.compact ? (peers.size / 6)  : peers.count} peers to #{request.ip} for torrent #{request.info_hash}."
        
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
        torrents = [] << Torrent.where(:_id => params["info_hash"].to_hex).only(:seeders, :leechers, :completed).first
      elsif @full_scrape
        torrents = Torrent.only(:seeders, :leechers, :completed)
      else
        return send_error("Full scrape is not permitted!")
      end
      
      out = {}
      torrents.each do |torrent|
        out.merge!({
          torrent.id.to_bin => {
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