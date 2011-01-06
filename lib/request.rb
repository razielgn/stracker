module STracker
  class Request
    REQ_KEYS = ["info_hash", "peer_id", "port", "uploaded", "downloaded", "left", "compact", "ip"]
  
    attr_reader :info_hash, :peer_id, :port, :uploaded, :downloaded, :left, :ip, :event, :key, :tracker_id, :compact, :numwant
  
    def initialize(request)
      if !validate(request)
        raise TrackerException, "Request was invalid!"
      end
    
      @info_hash = STracker::Tracker.bin2hex(request["info_hash"])
      @peer_id = request["peer_id"]
      @port = request["port"].to_i
      @uploaded = request["uploaded"].to_i
      @downloaded = request["downloaded"].to_i
      @left = request["left"].to_i
      @ip = request["ip"]
      @compact = !!(request["compact"] == 1)
    
      if request["event"]
        @event = request["event"]
      end
      if request["key"]
        @key = request["key"]
      end
      if request["tracker id"]
        @tracker_id = request["tracker id"]
      end
      if request["numwant"]
        @numwant = request["numwant"]
      end
    
      @numwant ||= 50
    end
  
    private
  
    def validate(request)
      keys = request.keys
      !REQ_KEYS.collect{|key| keys.include?(key)}.include?(false)
    end
  end
end