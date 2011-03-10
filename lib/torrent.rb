module STracker  
  class Torrent
    include Mongoid::Document
    store_in :torrents
  
    identity :type => String
    field :seeders, :type => Integer, :default => 0
    field :leechers, :type => Integer, :default => 0
    field :completed, :type => Integer, :default => 0
  
    embeds_many :peers, :class_name => "STracker::Peer"
  
    def update_torrent(request)
      # Checks if the peer was already in list
      peer = peers.select{|p| p.id == request.peer_id}.first
    
      # If not, adds it.
      if peer.nil?
        peer = Peer.new(:id => request.peer_id, :port => request.port,
                        :ip => request.ip, :last_announce => Time.now,
                        :downloaded => request.downloaded, :uploaded => request.uploaded,
                        :left => request.left)
        peers << peer
        peer.save
        
        inc(peer.left == 0 ? :seeders : :leechers, 1)
      else
        if request.event == "stopped"
          inc(peer.left == 0 ? :seeders : :leechers, -1)
          peer.delete
        end
        
        peer.update_self(request) 
        
        if request.event == "completed"
          inc(:completed, 1)
          inc(:seeders, 1)
          inc(:leechers, -1)
        end
      end
    end

    def clear_zombies(cutoff)
      zombies = peers.select{|p| p.last_announce <= cutoff}
      count = zombies.size
      
      if count > 0
        zombies.each do |zombie|
          inc(zombie.left == 0 ? :seeders : :leechers, -1)          
          zombie.delete
        end
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
        current = peers[(start += 1) % peers_size]
      
        if compact
          compact_s += current.get_compact
        else
          noncompact << current.get_noncompact
        end
      
        limit -= 1
      end
    
      compact ? compact_s : noncompact
    end
  
    private
  
    def min(value1, value2)
      (value1 > value2) ? value2 : value1
    end
  end
end