#!/bin/bash
# Script to dump CycleStreets data on a daily basis
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
	flock -n 9 || { echo 'CycleStreets daily dump is already running' ; exit 1; }

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
setupLogFile=$SCRIPTDIRECTORY/log.txt
touch ${setupLogFile}
#echo "#	CycleStreets daily backup in progress, follow log file with: tail -f ${setupLogFile}"
echo "$(date)	CycleStreets daily backup $(id)" >> ${setupLogFile}

# Ensure there is a cyclestreets user account
if [ ! id -u ${username} >/dev/null 2>&1 ]; then
	echo "$(date) User ${username} must exist: please run the main website install script" >> ${setupLogFile}
	exit 1
fi

# Ensure the main website installation is present
if [ ! -d ${websitesContentFolder}/data/routing -o ! -d $websitesBackupsFolder ]; then
	echo "$(date) The main website installation must exist: please run the main website install script" >> ${setupLogFile}
	exit 1
fi

# Ensure this script is run as cyclestreets user
if [ ! "$(id -nu)" = "${username}" ]; then
    echo "#	This script must be run as user ${username}, rather than as $(id -nu)." 1>&2
    exit 1
fi

#	Discard route batch files that are more than 7 days old
batchRoutes='www_routes_*.sql.gz'
find ${websitesBackupsFolder}/recentroutes -name "${batchRoutes}" -type f -mtime +7 -delete
find ${websitesBackupsFolder}/recentroutes -name "${batchRoutes}.md5" -type f -mtime +7 -delete

### Stage 2 - CycleStreets regular tasks for www
dumpPrefix=www

# Dump recent data
. ${SCRIPTDIRECTORY}/../utility/dump-recent.sh

# Flush photomap
# Clears out empty folders that sometimes result from failed uploads
find ${websitesContentFolder}/data/photomap -type d -name "original." -exec rmdir {} +
find ${websitesContentFolder}/data/photomap2 -type d -name "original." -exec rmdir {} +
find ${websitesContentFolder}/data/photomap3 -type d -name "original." -exec rmdir {} +

# Finish
echo "$(date)	All done" >> ${setupLogFile}

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
