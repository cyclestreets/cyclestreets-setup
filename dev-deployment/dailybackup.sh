#!/bin/bash
#
#       Backup CycleStreets development system
#
#       http://dev.cyclestreets.net/wiki/BackupStrategy
#
# Run as the cyclestreets user (a check is peformed after the config file is loaded).

# Avoid echoing if possible as this generates cron messages
# echo "#	CycleStreets Dev machine backup $(date)"

# Ensure this script is NOT run as root
if [ "$(id -u)" = "0" ]; then
    echo "#	This script must NOT be run as root." 1>&2
    exit 1
fi

### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The second single line solution from that page is probably good enough as it is unlikely that this script itself will be symlinked.
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Use this to remove the ../
ScriptHome=$(readlink -f "${DIR}/..")

# Name of the credentials file
configFile=${ScriptHome}/.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x ${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file."
    exit 1
fi

# Load the credentials
. ${configFile}

# Main body of script

# Ensure this script is run as cyclestreets user
if [ ! "$(id -nu)" = "${username}" ]; then
    echo "#	This script must be run as user ${username}, rather than as $(id -nu)."
    exit 1
fi

#	Check the backups folder is not empty
if [ -z "${websitesBackupsFolder}" ]; then
    echo "#	The backups folder is empty."
    exit 1
fi


# Logging
# Use an absolute path for the log file to be tolerant of the changing working directory in this script
setupLogFile=$DIR/log.txt
touch ${setupLogFile}
echo "#	CycleStreets Dev backup $(date)" >> ${setupLogFile}

# Bomb out if something goes wrong
set -e

##       Trac
dump=csTracBackup.tar.bz2

#	Park the old dump
if [ -d ${websitesBackupsFolder}/trac ]; then
    mv ${websitesBackupsFolder}/trac ${websitesBackupsFolder}/tracOld
fi

#	Dump
trac-admin /websites/dev/trac/cyclestreets hotcopy ${websitesBackupsFolder}/trac >> ${setupLogFile}

#	Archive
tar cjf ${websitesBackupsFolder}/${dump} -C ${websitesBackupsFolder} trac

#     Hash
openssl dgst -md5 ${websitesBackupsFolder}/${dump} > ${websitesBackupsFolder}/${dump}.md5

#	Tidyup
if [ -d ${websitesBackupsFolder}/tracOld ]; then
    # !! Very dodgy command
    rm -rf ${websitesBackupsFolder}/tracOld
fi

## !! WIP 19 Apr 2015 exit cleanly
exit 0

##	Subversion
dump=cyclestreetsRepo.dump.bz2

#      Dump
#	This takes almost half an hour in mid Feb 2012, and an hour in Jan 2013, with size 900M.
echo $password | sudo -S svnadmin dump /websites/svn/svn/cyclestreets -q | bzip2 > ${websitesBackupsFolder}/${dump}
#	Hash
openssl dgst -md5 ${websitesBackupsFolder}/${dump} > ${websitesBackupsFolder}/${dump}.md5


#	Finally
echo "#	Completed at $(date)" >> ${setupLogFile}

#	Ends
