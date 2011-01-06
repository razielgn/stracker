require File.dirname(__FILE__) + "/server.rb"

if ENV["HEROKU"] # dunno why this doesn't work on my mac
  run STracker::SinatraTracker
else # and this doesn't work on Heroku!
  STracker::SinatraTracker.run!
end