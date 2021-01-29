# FallBack Deployment

Fallback runs scripts at regular intervals to pull files from live servers.

## Daily update did not complete
If you are directed here from a cron email it is because the [check-fallback.sh](https://github.com/cyclestreets/cyclestreets-setup/blob/master/fallback-deployment/check-fallback.sh) script has determined that the daily fallback has not completed.

Examine [daily-update.sh](https://github.com/cyclestreets/cyclestreets-setup/blob/master/fallback-deployment/daily-update.sh) script to diagnose and the log file in this folder on the backup may have more.
