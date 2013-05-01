# BitTorrent Tracker

## Configuration
To change config see config/tracker.yaml

* **tracker_id**: String. It is also reported to the clients.
* **announce_interval**: In seconds.
* **timeout_interval**: In seconds. After the timeout the zombie peers will be purged.
* **min_announce_interval**: In seconds.
* **allow_unregistered_torrents**: Bool. A la opentracker or not, your choice!
* **allow_noncompact**: Bool. Compact responses save bandwidth.
* **full_scrape**: Bool. Decide if a full tracker scrape is permitted. It is useful to indexing websites.
* **mongodb_uri**: mongodb://user:pass@somewhere.com/database
