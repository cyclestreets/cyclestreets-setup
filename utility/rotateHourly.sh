#!/bin/bash
#	This script should run on the backup machine, every hour.
#	It rotates the backups relative to the folder
#	The arguments are:
#	1. folder relative to root (not slash terminated) e.g. /websites/cyclescape/backup
#	2. name of the archive file e.g. cyclescapeDB.sql.gz

folder=$1
archive=$2

#	Folder locations
hourlyFolder=${folder}/rotation/hourly/$(date +"%H")

#	Recreate the new backup folder - if necessary
mkdir -p ${hourlyFolder}

#	Update the backup folder modified time - so its easy to see which is the newest
touch ${hourlyFolder}

#	Copy the backup to that folder
cp -p ${folder}/${archive} ${hourlyFolder}

# End of file
