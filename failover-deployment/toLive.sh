#!/bin/bash
#	When the failover is running as the live server, this script can be used to generate files to keep live machine in sync.
#	It should be run manually on the failover machine, as user cyclestreets.

### Stage 1 - general setup

# Ensure this script is NOT run as root (it should be run as cyclestreets)
if [ "$(id -u)" = "0" ]; then
    echo "#	This script must NOT be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

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

# Use this to remove the ../
ScriptHome=$(readlink -f "${DIR}/..")

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
echo "#	CycleStreets toLive in progress, follow log file with: tail -f ${setupLogFile}"
echo "$(date)	CycleStreets toLive $(id)" >> ${setupLogFile}

# Ensure live machine has been defined
if [ -z "${liveMachineAddress}" ]; then
    echo "# A live machine must be defined in order to run updates" >> ${setupLogFile}
    exit 1
fi

# Ensure there is a cyclestreets user account
if [ ! id -u ${username} >/dev/null 2>&1 ]; then
	echo "$(date) User ${username} must exist: please run the main website install script" >> ${setupLogFile}
	exit 1
fi

# Ensure this script is run as cyclestreets user
if [ ! "$(id -nu)" = "${username}" ]; then
    echo "#	This script must be run as user ${username}, rather than as $(id -nu)." 1>&2
    exit 1
fi

# Ensure the main website installation is present
if [ ! -d ${websitesContentFolder}/data/routing -o ! -d $websitesBackupsFolder ]; then
	echo "$(date) The main website installation must exist: please run the main website install script" >> ${setupLogFile}
	exit 1
fi

### Stage 2
dumpPrefix=failover

# Dump recent data
. ${SCRIPTDIRECTORY}/../utility/dump-recent.sh

# Restore these cronjobs
cat <(crontab -l) <(echo "49 7 * * * ${ScriptHome}/failover-deployment/csDevDownloadAndRotateDaily.sh") | crontab -
cat <(crontab -l) <(echo "19 * * * * ${ScriptHome}/failover-deployment/cyclescapeDownloadAndRotateHourly.sh") | crontab -
cat <(crontab -l) <(echo "5 5 * * * ${ScriptHome}/failover-deployment/daily-update.sh") | crontab -
cat <(crontab -l) <(echo "0 10 * * * ${ScriptHome}/import-deployment/import.sh") | crontab -

# Finish
echo "$(date)	All done" >> ${setupLogFile}

# End of file
