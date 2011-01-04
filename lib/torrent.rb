module STracker
  class Torrent
    include Mongoid::Document
  
    identity :type => String
    field :seeders, :type => Integer, :default => 0
    field :leechers, :type => Integer, :default => 0
    field :completed, :type => Integer, :default => 0
  
    embeds_many :peers
  
    def update_torrent(request)
      # Checks if the peer was already in list
      peer = self.peers.select{|p| p.id == request.peer_id}.first
    
      # If not, adds it.
      if peer.nil?
        peer = add_peer(request)
        self.peers << peer
      else
        peer.update(request)
      end
      
      if peer.left == 0
        self.seeders += 1
      else
        self.leechers += 1
      end
      
      self.completed += 1 if request.event == "completed"
      
      self.save
    end

    def clear_zombies(cutoff)
      zombies = self.peers.select{|p| p.last_announce <= cutoff}
      count = zombies.size
      
      if count > 0
        zombies.each {|zombie| zombie.delete }
        self.save 
      end
      
      count
    end
  
    def get_peers(numwant, compact)
      peers_size = self.peers.size
      limit = min(numwant.to_i, peers_size)
      srand(Time.now.to_i)
      start = rand(peers_size)
    
      compact_s = ""
      noncompact = []
    
      while (limit > 0)
        current = self.peers[(start += 1) % peers_size]
      
        if compact
          compact_s += current.get_compact
        else
          noncompact << current.get_noncompact
        end
      
        limit -= 1
      end
    
      if compact
        compact_s
      else
        noncompact
      end
    end
  
    private
  
    def add_peer(request)
      peer = Peer.new(:id => request.peer_id,
                      :port => request.port,
                      :ip => request.ip,
                      :last_announce => Time.now)
    end
  
    def min(n1, n2)
      if n1 > n2; n2; else n1; end;
    end
  end
end