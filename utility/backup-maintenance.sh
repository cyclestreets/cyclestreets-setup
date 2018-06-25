#!/bin/bash
#
# This is a daily maintenance script for backup deployments of CycleStreets.

# Ensure this script is NOT run as root (it should be run as cyclestreets)
if [ "$(id -u)" = "0" ]; then
    echo "#	This script must NOT be run as root." 1>&2
    exit 1
fi

#	Make sure the latest code is present, use quiet option to suppress output
git pull -q /websites/www/content/


#	Delete previously generated routing database, tables and tsv files to conserve space.
# The following find command selects top-level files in the given path that are older than 24 hours and deletes them.
# It works as follows:
# Backup folder is supplied
# -maxdepth option restricts find to that folder
# ! (which is escaped) negates the next test.
# -mtime 0 finds files modified within the last 24 hours
# -type f finds only files

# !! Needs checking whether this is still a useful/relevant cleanup
# find /websites/www/backups -maxdepth 1 -type f -name "routing*\.gz" \! -mtime 0 -type f -delete


# End of file
