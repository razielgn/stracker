class String
  def to_hex
    (self.unpack "H*").first
  end
  
  def to_bin
    [self].pack "H*"
  end
  
  def to_bool
    self.to_i == 0 ? false : true
  end
end