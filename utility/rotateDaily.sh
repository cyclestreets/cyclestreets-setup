#!/bin/bash
#	This script should run on the backup machine every day.
#	It rotates the backups relative to the folder
#	The arguments are:
#	1. folder relative to root (not slash terminated) e.g. /websites/cyclescape/backup
#	2. name of the archive file e.g. cyclescapeShared.tar.bz2

folder=$1
archive=$2

#	Folder locations
dailyFolder=${folder}/rotation/daily/$(date +"%u")

#	Recreate the new backup folder - if necessary
mkdir -p ${dailyFolder}

#	Update the backup folder modified time - so its easy to see which is the newest
touch ${dailyFolder}

#	Copy the backup to that folder
cp -p ${folder}/${archive} ${dailyFolder}

# End of file
