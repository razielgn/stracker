require 'spec_helper'

describe "Tracker" do
  include Rack::Test::Methods
  include STracker

  def app
    @app ||= STracker::SinatraTracker
  end
  
  describe "When a tracker is empty" do
    before do
      Torrent.collection.remove
    end
    
    it "should return error on /announce without correct parameters" do
      get '/announce'
      last_response.status.should == 200
      last_response.headers["Content-Type"].should == "text/plain;charset=utf-8"
    end

    it "should return error on /scrape without torrents in the db" do
      get '/scrape'
      last_response.status.should == 200
      last_response.headers["Content-Type"].should == "text/plain;charset=utf-8"
      last_response.body.should == "d14:failure reason21:The tracker is empty!e"
    end

    it "should respond to /status with a correct view" do
      get '/status'
      last_response.status.should == 200
      last_response.body.should include("Configuration")
    end
    
    describe "and an user performs an announce" do
      it "should add the torrent if torrent is unknown and tracker tracks everything" do
      end
      
      it "should give error if torrent is not known and tracker doesn't track everything" do
      end
    end
  end
  
  describe "When a tracker is populated" do
    before do
      Torrent.collection.remove
      fill_tracker
    end
    
    it "should return the correct /scrape with all the torrents in the db" do
      get '/scrape'
      last_response.status.should == 200
      last_response.headers["Content-Type"].should == "text/plain;charset=utf-8"
      
      last_response.body.bdecode["files"].count.should == 100
    end
    
    it "should respond to /status with a correct view" do
      get '/status'
      last_response.status.should == 200
      last_response.body.should include(random_hash)
    end
    
    it "should return compact announce response on compact request" do
      get "/announce?info_hash=#{fake_torrents.first}&peer_id=#{rand % 100000}&port=666&uploaded=0&downloaded=0&left=666&compact=1"
      last_response.status.should == 200
      response = last_response.body.bdecode
      response["complete"].should == 0
      response["downloaded"].should == 0
      response["incomplete"].should == 1
      response["peers"].size.should == 6
    end
    
    it "should return non-compact announce response on non-compact request" do
      get "/announce?info_hash=#{fake_torrents.first}&peer_id=#{rand % 100000}&port=666&uploaded=0&downloaded=0&left=666&compact=0"
      last_response.status.should == 200
      response = last_response.body.bdecode
      response["complete"].should == 0
      response["downloaded"].should == 0
      response["incomplete"].should == 1
      response["peers"].class.should == Array
      response["peers"].count.should == 1
    end
  end
end