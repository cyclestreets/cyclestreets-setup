# A scriptlet called from import.sh which is setup for running as passwordless sudo in /etc/sudoers.d/cyclestreets

# Deletes coverage files from tmp
find /tmp/ -maxdepth 1 -type f -name 'coverage*.csv' -delete
