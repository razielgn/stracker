module STracker  
  class Torrent
    include Mongoid::Document
  
    identity :type => String
    field :seeders, :type => Integer, :default => 0
    field :leechers, :type => Integer, :default => 0
    field :completed, :type => Integer, :default => 0
  
    embeds_many :peers, :class_name => "STracker::Peer"
  
    def update_torrent(request, min_announce)
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
        
        if peer.left == 0
          inc(:seeders, 1)
        else
          inc(:leechers, 1)
        end
      else
        if (Time.now - peer.last_announce) < min_announce
          raise TrackerException.new "Respect the announce interval!"
        end
        
        peer.update_self(request) 
        
        if request.event == "completed"
          inc(:completed, 1)
          inc(:seeders, 1)
          dec(:leechers, 1)
        end
      end
    end

    def clear_zombies(cutoff)
      zombies = peers.select{|p| p.last_announce <= cutoff}
      count = zombies.size
      
      if count > 0
        zombies.each do |zombie|
          if zombie.left == 0
            inc(:seeders, -1)
          else
            inc(:leechers, -1)
          end
          
          zombie.delete
        end
        
        save 
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
    
      if compact
        compact_s
      else
        noncompact
      end
    end
  
    private
  
    def min(n1, n2)
      if n1 > n2; n2; else n1; end;
    end
  end
end