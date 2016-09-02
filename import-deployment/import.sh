#!/bin/bash
# Script to run an import of fresh CycleStreets data on Ubuntu
# Written for Ubuntu Server 16.04 LTS (View Ubuntu version using 'lsb_release -a')
#
# Run as the cyclestreets user (a check is peformed after the config file is loaded).

# When in fallback mode uncomment the next two lines:
#echo "# Skipping in fallback mode"
#exit 1

# Start an import run
echo "#	$(date) CycleStreets import"

# Ensure this script is NOT run as root
if [ "$(id -u)" = "0" ]; then
    echo "#	This script must not be be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

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
    echo "#	The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. ${configFile}


## Main body of script

# Ensure this script is run as cyclestreets user
if [ ! "$(id -nu)" = "${username}" ]; then
    echo "#	This script must be run as user ${username}, rather than as $(id -nu)." 1>&2
    exit 1
fi

# Check the import folder is defined
if [ -z "${importContentFolder}" ]; then
    echo "#	The import folder is not defined."
    exit 1
fi

# The new routing edition will be written to this location
importMachineEditions=${importContentFolder}/output

#	Report where logging is occurring
echo "#	Progress is logged in ${importContentFolder}/log.txt"

# When an import disk has been specified in the config, check it has enough free space
if [ -n "${importDisk}" ]; then

    # Get free disk space in Gigabytes
    # http://www.cyberciti.biz/tips/shell-script-to-watch-the-disk-space.html
    # !! Note: this check is rather machine-specific as it happens that on our machine the key disk is at /dev/sda1 which will not be true in general.
    freeSpace=$(df -BG ${importDisk} | grep -vE '^Filesystem' | awk '{ print $4 }')

    # Remove the G                                                                                                                                                            
    # http://www.cyberciti.biz/faq/bash-remove-last-character-from-string-line-word/
    freeSpace="${freeSpace%?}"

    # Amount of free space required in Gigabytes
    needSpace=80

    if [ "${freeSpace}" -lt "${needSpace}" ];
    then
        echo "#	Import: freespace is ${freeSpace}G, but at least ${needSpace}G are required."
        exit 1
    fi
fi

# Guess the likely name of the routing edition, which is usually routingYYMMDD
likelyEdition=routing$(date +%y%m%d)

# Check whether the edition already exists either as a directory or symbolic link
if [ -d ${importMachineEditions}/${likelyEdition} -o -L ${importMachineEditions}/${likelyEdition} ]; then
    echo "#	The edition already exists, check this folder: ${importMachineEditions}/${likelyEdition}"

    # !! An argument could be used to force this to continue
    if [ "$1" != 'force' ]; then
	echo "#	Abandoning - use force option to override"
	exit 1
    else
	echo "#	Continuing due to force option"
    fi
fi

# Lock directory
lockdir=/var/lock/cyclestreets
mkdir -p $lockdir

# Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 9 || { echo '#	An import is already running' ; exit 1; }

# Removes coverage files - requires passwordless sudo
sudo ${ScriptHome}/utility/removeCoverageCSV.sh

# Stop the routing service - if it is installed
if [ -e ${routingDaemonLocation} -a -n "${stopRoutingDuringImport}" ]; then

    # Stop the routing service (the cyclestreets user should have passwordless sudo access to this command)
    sudo ${routingDaemonLocation} stop
fi

#       Move to the right place
cd ${importContentFolder}

#       Start the import (which sets a file lock called /var/lock/cyclestreets/importInProgress to stop multiple imports running)
php run.php

# Restart mysql - as setup for passwordless sudo by the installer. This resets the MySQL configuration to default values, more suited to serving web pages and routes.
echo "#	$(date)	Restarting MySQL to restore default configuration."
sudo service mysql restart

# Read the folder of routing editions, one per line, newest first, getting first one
latestEdition=`ls -1t ${importMachineEditions} | head -n1`

# Report completion and next steps
echo "#	$(date)	CycleStreets import has created a new edition: ${latestEdition}"
echo "#	To prepare this data for serving locally, remotely or both:"
echo "#	Locally  run: ${ScriptHome}/live-deployment/installLocalLatestEdition.sh"
echo "#	Remotely run: ${username}@other:${ScriptHome}/live-deployment\$ ./install-routing-data.sh"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
