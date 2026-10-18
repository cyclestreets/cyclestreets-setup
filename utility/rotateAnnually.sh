#!/bin/bash
#	This script should run on the backup machine, every year.
#	It rotates the backups relative to the folder
#	The arguments are:
#	1. folder relative to root (not slash terminated) e.g. /websites/cyclescape/backup
#	2. name of the archive file e.g. cyclescapeShared.tar.bz2
#	3. all files beginning with the name are copied e.g. the *.md5 files
# Abandon on empty arguments
if [ -z "$1" -o  -z "$2" ]; then
	echo "$(date) Empty arguments to $0"
	exit 1
fi


folder=$1
archive=$2

#	Folder locations
annuallyFolder=${folder}/rotation/annually/$(date +"%Y")

#	Recreate the new backup folder - if necessary
mkdir -p ${annuallyFolder}

#	Update the backup folder modified time - so its easy to see which is the newest
touch ${annuallyFolder}

#	Copy files beginning with that backup name to that folder
cp -p ${folder}/${archive}* ${annuallyFolder}

# End of file
