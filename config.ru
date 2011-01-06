require File.dirname(__FILE__) + "/server.rb"

if ENV["HEROKU"]
  run STracker::SinatraTracker
else
  STracker::SinatraTracker.run!
end