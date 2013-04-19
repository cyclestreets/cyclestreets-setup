#!/bin/bash
#	Rotates the CycleStreets backups weekly.

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
	flock -n 9 || { echo 'CycleStreets weekly rotate is already in progress' ; exit 1; }

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


# Main body

#	Folder locations
folder=${websitesBackupsFolder}
rotateWeekly=${SCRIPTDIRECTORY}/../utility/rotateWeekly.sh

#	CycleStreets Rotate
$rotateWeekly $folder www_cyclestreets.sql.gz
$rotateWeekly $folder www_schema_blogcyclestreets_database.sql.gz
$rotateWeekly $folder www_schema_blogcyclescape_database.sql.gz
#	CS Dev rotation
$rotateWeekly $folder csTracBackup.tar.bz2
$rotateWeekly $folder cyclestreetsRepo.dump.bz2

#	Cyclescape Folder locations
folder=/websites/cyclescape/backup
$rotateWeekly $folder cyclescapeDB.sql.gz
$rotateWeekly $folder toolkitShared.tar.bz2


# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
