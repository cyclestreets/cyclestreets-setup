#!/bin/bash
#	This file is one of the cyclestreets backup tasks that runs on the backup machine.
#
#	This file downloads dumps from dev.cyclestreets.net to the backup machine.
#
#	The server should generate backups of
#	* subversion repository
#	* trac
#	as zipped files.
#	Both files should also have .md5 files containing the md5 strings associated with them.
#	This script looks at the remote md5 files to determine whether they and the dumps are ready to download.

# This script is idempotent - it can be safely re-run without destroying existing data.

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
	flock -n 9 || { echo 'CycleStreets Dev Download is already running' ; exit 1; }

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
echo "$(date)	CycleStreets Dev Download $(id)" >> ${setupLogFile}


### Main body of file

#	Download and restore the CycleStreets database.
#	Folder locations
server=dev.cyclestreets.net
folder=${websitesBackupsFolder}
download=${SCRIPTDIRECTORY}/../utility/downloadDumpAndMd5.sh
rotateDaily=${SCRIPTDIRECTORY}/../utility/rotateDaily.sh

#	Folder locations

#	Download CycleStreets repository backup
$download $administratorEmail $server $folder cyclestreetsRepo.dump.bz2

#	Download CycleStreets Trac backup
$download $administratorEmail $server $folder csTracBackup.tar.bz2


#	Rotate
$rotateDaily $folder cyclestreetsRepo.dump.bz2
$rotateDaily $folder csTracBackup.tar.bz2


### Final Stage

# Finish
echo "$(date)	All done" >> ${setupLogFile}

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
