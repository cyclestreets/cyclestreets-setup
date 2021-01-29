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

# This script is called by cron.
# Check the daily fallback log wrote a success message having today's date.
# Items are logged using: date --iso-8601=seconds which is this format: 2021-01-29T12:40:47+00:00
# This pattern searches for the date followed by multiple non-whitespace (upper S) and then a single space (lower s)
todayDatePattern="$(date +%Y-%m-%d)\S\+\s"
inComplete=

# Check the log for confirmation that the item give as first argument has completed
checkItemDone ()
{
    local item=$1
    if ! grep -q "${todayDatePattern}${item} done" "${logFile}"; then
	# Set or append to the list of incomplete items
	[[ -z "${inComplete}" ]] && inComplete=${item} || inComplete="${inComplete}, ${item}"
    fi
}

# Do the checks
checkItemDone "CycleStreets daily backup"
checkItemDone "CycleStreets daily rotation"
checkItemDone "Cyclescape daily backup"
checkItemDone "Cyclescape daily rotation"

# Report
if [ -n "${inComplete}" ]; then
    message="The daily backup did not complete today.\n\nThe following items did not complete: ${inComplete}\n\nhttps://github.com/cyclestreets/cyclestreets-setup/blob/master/backup-deployment/README.md#daily-backup-did-not-complete\n\n\tYours,\n\n\t\tbackup cron"
    # Send mail
    recipientMail="${administratorEmail/webmaster/info}"
    echo -e ${message} | mail -s "Backup cron did not complete today" ${recipientMail}

    # Report (so that will appear in cron email)
    echo -e ${message}
fi

# Finish
echo "$(date --iso-8601=seconds)	Checked" >> ${logFile}

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
