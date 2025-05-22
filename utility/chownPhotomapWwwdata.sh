# A scriptlet called from sync-recent.sh and restore-recent.sh which is setup for running as passwordless sudo in /etc/sudoers.d/cyclestreets
# The other methods for running these commands as sudo generate some output which ends up in an email from cron.

# Need to bind from an argument because this script is called by sudo
websitesContentFolder=$1

# Set so that www-data owns the files in these folders
chown -R www-data ${websitesContentFolder}/data/photomap
chown -R www-data ${websitesContentFolder}/data/photomap2
chown -R www-data ${websitesContentFolder}/data/photomap3

# This is filled by class settingsAssignment
chown -R www-data ${websitesContentFolder}/documentation/RequestedMissingCities.tsv

# Avoid mkstemp errors (from rsync in sync-recent.sh) by adding group writing permissions
chmod g+w -R ${websitesContentFolder}/data/photomap*
