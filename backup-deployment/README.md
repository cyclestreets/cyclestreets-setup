# Backup Deployment

Backup runs scripts at regular intervals to pull files from live servers.

## Daily backup did not complete
If you are directed here from a cron email it is because the [check-backup.sh](https://github.com/cyclestreets/cyclestreets-setup/blob/master/backup-deployment/check-backup.sh) script has determined that the daily backup has not completed.

Examine [daily-backup.sh](https://github.com/cyclestreets/cyclestreets-setup/blob/master/backup-deployment/daily-backup.sh) script to diagnose.
