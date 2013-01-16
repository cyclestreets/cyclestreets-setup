#!/bin/bash
#
# This is a daily maintenance script for backup deployments of CycleStreets.

#	User cyclestreets (rather than root) for safety
asCS="sudo -u cyclestreets"

#	Make sure the latest code is present
${asCS} svn update /websites/www/content/

#	Delete previously generated routing database, tables and tsv files to conserve space.
# The following find command selects top-level files in the given path that are older than 24 hours and deletes them.
# It works as follows:
# Backup folder is supplied
# -maxdepth option restricts find to that folder
# ! (which is escaped) negates the next test.
# -mtime 0 finds files modified within the last 24 hours
# -type f finds only files

# !! Needs checking whether this is still a useful/relevant cleanup
# ${asCS} find /websites/www/backups -maxdepth 1 -type f -name "routing*\.gz" \! -mtime 0 -type f -delete


# End of file
