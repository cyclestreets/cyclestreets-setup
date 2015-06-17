# A scriptlet called from restore-recent.sh which is setup for running as passwordless sudo in /etc/sudoers.d/cyclestreets
# The other methods for running these commands as sudo generate some output which ends up in an email from cron.

# Set so that www-data owns the files in these folders
chown -R www-data ${websitesContentFolder}/data/photomap
chown -R www-data ${websitesContentFolder}/data/photomap2
chown -R www-data ${websitesContentFolder}/data/photomap3
chown -R www-data ${websitesContentFolder}/data/synchronization

# This is filled by class settingsAssignment
chown -R www-data ${websitesContentFolder}/documentation/RequestedMissingCities.tsv
