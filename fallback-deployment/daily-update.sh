#!/bin/bash
# Script to update CycleStreets fallback

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
	flock -n 9 || { echo 'CycleStreets fallback update is already running' ; exit 1; }


### DEFAULTS ###

# Controls syncing and restoration of recent route zips: true or empty
restoreRecentRoutes=

# Fallback deployment restores the cyclestreets database to one having this name
csFallbackDb=cyclestreets


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
setupLogFile=$SCRIPTDIRECTORY/log.txt
touch ${setupLogFile}
#echo "#	CycleStreets fallback update in progress, follow log file with: tail -f ${setupLogFile}"
echo "$(date --iso-8601=seconds)	CycleStreets fallback update" >> ${setupLogFile}

# Ensure a fallback database name is set
if [ -z "${csFallbackDb}" ]; then
    echo "$(date --iso-8601=seconds) Set a fallback database name to restore."
    exit 1
fi

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

# Ensure the main website installation is present
if [ ! -d ${websitesContentFolder}/data/routing -o ! -d $websitesBackupsFolder ]; then
    echo "$(date --iso-8601=seconds) The main website installation must exist: please run the main website install script"
    exit 1
fi

### Stage 2 - CycleStreets regular tasks for www

#	Download and restore the CycleStreets database.
#	This section is simlar to fallback-deployment/fromFallback.sh
#	Folder locations
server=www.cyclestreets.net
dumpPrefix=www

# Useful binding
# The defaults-extra-file is a positional argument which must come first.
superMysql="mysql --defaults-extra-file=${mySuperCredFile} -hlocalhost"

#	The fallback server is running a custom routing service while this update happens
#	Record current routing edition and apiV2Url
currentEdition=$(${superMysql} -NB cyclestreets -e "select routingDb from map_config where id = 1;")
currentApiV2Url=$(${superMysql} -NB cyclestreets -e "select apiV2Url from map_config where id = 1;")

# Restore recent data
. ${SCRIPTDIRECTORY}/../utility/sync-recent.sh
. ${SCRIPTDIRECTORY}/../utility/restore-recent.sh

#	Discard route batch files that are exactly 7 days old
#	!! Consider moving this to restore-recent.sh - deleting the files after they have been applied to the database.
if [ "$restoreRecentRoutes" = true ]; then
    find ${folder}/recentroutes -maxdepth 1 -name "${batchRoutes}" -type f -mtime 7 -delete
    find ${folder}/recentroutes -maxdepth 1 -name "${batchRoutes}.md5" -type f -mtime 7 -delete
fi

#	Restore current routing edition and apiV2Url
${superMysql} ${csFallbackDb} -e "update map_config set routingDb = '${currentEdition}', apiV2Url = '${currentApiV2Url}';";

#	Prohibit new photomap uploads while in fallback mode (they would be lost when returning to normality)
${superMysql} ${csFallbackDb} -e "update map_config set photomapStatus = 'closed';";

#	Enforce sign-in to avoid this fallback server being spidered while in normal mode
${superMysql} ${csFallbackDb} -e "update map_config set enforceSignin = 'yes';";

# Finish (the presence of this exact text is sought by check-fallback.sh)
echo "$(date --iso-8601=seconds)	Fallback update done" >> ${setupLogFile}

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
