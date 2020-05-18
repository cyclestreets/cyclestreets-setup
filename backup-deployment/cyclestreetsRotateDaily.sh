#!/bin/bash
#	Rotates the CycleStreets backups daily.

### Stage 1 - general setup

# Ensure this script is NOT run as root (it should be run as cyclestreets)
if [ "$(id -u)" = "0" ]; then
    echo "#	This script must NOT be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

# Lock directory
lockdir=/var/lock/cyclestreets
mkdir -p $lockdir

# Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 9 || { echo 'CycleStreets daily rotate is already in progress' ; exit 1; }

### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The multi-line method of geting the script directory is needed because this script is likely symlinked from cron
SOURCE="${BASH_SOURCE[0]}"
DIR="$( dirname "$SOURCE" )"
while [ -h "$SOURCE" ]
do 
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
  DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPTDIRECTORY=$DIR

# Define the location of the credentials file relative to script directory
configFile=../.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x $SCRIPTDIRECTORY/${configFile} ]; then
    echo "# The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. $SCRIPTDIRECTORY/${configFile}

# Logging
logFile=$SCRIPTDIRECTORY/log.txt
touch ${logFile}
echo "$(date)	CycleStreets daily rotation" >> ${logFile}

# Main body

#	Folder locations
folder=${websitesBackupsFolder}
rotateDaily=${SCRIPTDIRECTORY}/../utility/rotateDaily.sh

#	Rotate
$rotateDaily $folder www_cyclestreets.sql.gz
$rotateDaily $folder www_csBatch_jobs_servers_threads.sql.gz

#	Microsites
folder=/websites/microsites/backup
$rotateDaily $folder microsites_websites.tar.bz2

echo "$(date)	CycleStreets daily rotation done" >> ${logFile}

#	Cyclescape
folder=/websites/cyclescape/backup
$rotateDaily $folder cyclescapeDB.sql.gz
$rotateDaily $folder cyclescapeShared.tar.bz2

echo "$(date)	Cyclescape daily rotation done" >> ${logFile}

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
