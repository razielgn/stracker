require 'ip'

module STracker
  class Peer
    include Mongoid::Document
  
    identity :type => String
    field :ip, :type => String
    field :port, :type => Integer
    field :last_announce, :type => Time
  
    field :downloaded, :type => Integer, :default => 0
    field :uploaded, :type => Integer, :default => 0
    field :left, :type => Integer
  
    embedded_in :torrent, :inverse_of => :peers
  
    def update(request)
      self.ip = request.ip
      self.port = request.port
      self.downloaded = request.downloaded
      self.uploaded = request.uploaded
      self.left = request.left
      self.last_announce = Time.now
    end
  
    def get_compact
      if self.ip =~ //
        octets = IP::Address::IPv4.new(self.ip).octets
      elsif self.ip =~ //
        octets = IP::Address::IPv6.new(self.ip).octets
      end
    
      if self.port < 256
        port_hex = "\x00" + [self.port.to_s(16).hex].pack("C")
      else
        port_hex = [self.port.to_s(16).hex].pack("C")
      end

      "#{octets.collect{|o| [o.to_s(16).hex].pack "C"}.join}#{port_hex}"
    end
  
    def get_noncompact
      {"peer id" => self.id,
       "ip" => self.ip,
       "port" => self.port}
    end
  end
end