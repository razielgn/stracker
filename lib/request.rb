module STracker
  class Request
    @@req_keys = ["info_hash", "peer_id", "port", "uploaded", "downloaded", "left", "compact", "ip"]
    @@pars_keys = ["to_hex", "to_hex", "to_i", "to_i", "to_i", "to_i", "to_bool", "to_s"]
    
    attr_reader :numwant, :event
    
    def initialize(request)
      if not valid?(request)
        raise TrackerException, "Request was invalid!"
      end
      
      request.each_pair do |key, value|
        meta.send :attr_reader, key.to_sym
        
        if @@req_keys.include? key
          value = value.send @@pars_keys[@@req_keys.index key]
        end
        
        instance_variable_set("@#{key}", value)
      end
    
      @event ||= "started"
      @numwant ||= 30
    end
  
    private
  
    def valid?(request)
      keys = request.keys
      not @@req_keys.collect{|key| keys.include?(key)}.include?(false)
    end
    
    def meta
      class << self
        self
      end
    end
  end
end