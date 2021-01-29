#!/bin/bash
# Script to backup CycleStreets on a daily basis
# Tested on 12.10 (View Ubuntu version using 'lsb_release -a')

# This script is idempotent - it can be safely re-run without destroying existing data.
# It should be run as cyclestreets user - a check for that occurs below.

### Stage 1 - general setup

# Ensure this script is NOT run as root
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
	flock -n 9 || { echo 'CycleStreets daily backup is already running' ; exit 1; }


### DEFAULTS ###

# Microsites server such as blogs
micrositesServer=


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
    echo "# The config file, ${configFile}, does not exist or is not executable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. $SCRIPTDIRECTORY/${configFile}

# Logging
logFile=$SCRIPTDIRECTORY/log.txt
touch ${logFile}
echo "$(date --iso-8601=seconds)	CycleStreets daily backup" >> ${logFile}

# Ensure there is a cyclestreets user account
if [ ! id -u ${username} >/dev/null 2>&1 ]; then
    echo "$(date --iso-8601=seconds) User ${username} must exist: please run the main website install script"
    exit 1
fi

# Ensure this script is run as cyclestreets user
if [ ! "$(id -nu)" = "${username}" ]; then
    echo "#	This script must be run as user ${username}, rather than as $(id -nu)."
    exit 1
fi


### Stage 2 - CycleStreets regular tasks for www

#	Copy the CycleStreets database dump
#	Folder locations
server=www.cyclestreets.net
dumpPrefix=www

# Backup recent data
. ${SCRIPTDIRECTORY}/../utility/sync-recent.sh

#	Download microsites websites backup and databases dump
if [ -n "${micrositesServer}" ]; then
    folder=${websitesBackupsFolder}
    download=${SCRIPTDIRECTORY}/../utility/downloadDumpAndMd5.sh
    $download $administratorEmail $micrositesServer $folder microsites_websites.tar.bz2
    $download $administratorEmail $micrositesServer $folder microsites_allDatabases.sql.gz

    # Move them
    micrositesBackupsFolder=/websites/microsites/backup
    mv ${folder}/microsites_websites.tar.bz2* $micrositesBackupsFolder
    mv ${folder}/microsites_allDatabases.sql.gz* $micrositesBackupsFolder
fi

# Finish (the presence of this exact text is sought by check-backup.sh)
echo "$(date --iso-8601=seconds)	CycleStreets daily backup done" >> ${logFile}

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
