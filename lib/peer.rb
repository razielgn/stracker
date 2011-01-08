module STracker
  class Peer
    include Mongoid::Document

    identity :type => String
    field :ip, :type => String
    field :port, :type => Integer
    field :last_announce, :type => Time

    field :downloaded, :type => Integer, :default => 0
    field :uploaded, :type => Integer, :default => 0
    field :left, :type => Integer, :default => -1

    embedded_in :torrent, :inverse_of => :peers

    def update_self(request)      
      self.ip = request.ip
      self.port = request.port
      self.downloaded = request.downloaded
      self.uploaded = request.uploaded
      self.left = request.left
      self.last_announce = Time.now
      
      save
    end

    def get_compact
      ip = self.ip.split('.').collect{|n| [n.to_i.to_s(16)].pack("H2")}.join
      port = [self.port.to_s(16)].pack("H4")
    
      "#{ip}#{port}"
    end

    def get_noncompact
      {"peer id" => self.id,
       "ip" => self.ip,
       "port" => self.port}
    end
  end
end