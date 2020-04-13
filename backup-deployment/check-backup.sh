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
    echo "# The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. $SCRIPTDIRECTORY/${configFile}

# Logging
setupLogFile=$SCRIPTDIRECTORY/log.txt

# Called by the cron
# Check the daily backup log wrote a success message having today's date.
todayDatePattern="$(date +%a\ %b\ %_d) [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\} [A-Z]\{3\} $(date +%Y)"
didnotComplete=

#	Check CycleStreets
completedMsg="Daily CycleStreets backup done"
if ! grep -q "${todayDatePattern}\s${completedMsg}" "${setupLogFile}"; then
	didnotComplete=CycleStreets
fi

#	Check Cyclescape
completedMsg="Daily Cyclescape backup done"
if ! grep -q "${todayDatePattern}\s${completedMsg}" "${setupLogFile}"; then
	didnotComplete="${didnotComplete} Cyclescape"
fi

# Report
if [ -n "${didnotComplete}" ]; then
    message="The daily backup did not complete today.\n\nThe module(s) that did not complete were:${didnotComplete}\n\nhttps://github.com/cyclestreets/cyclestreets-setup/blob/master/backup-deployment/README.md#daily-backup-did-not-complete\n\n\tYours,\n\t\tbackup cron"
    # Send mail
    recipientMail="${administratorEmail/webmaster/info}"
    echo -e ${message} | mail -s "Backup cron did not complete today" ${recipientMail}

    # Report (so that will appear in cron email)
    echo -e ${message}
fi

# Finish
echo "$(date)	Checked" >> ${setupLogFile}

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
