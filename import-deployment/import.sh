#!/bin/bash
# Script to run an import of fresh CycleStreets data on Ubuntu
# Tested on 14.04.2 LTS Desktop (View Ubuntu version using 'lsb_release -a')

# When in failover mode uncomment the next two lines:
#echo "# Skipping in failover mode"
#exit 1

# Start an import run

echo "#	CycleStreets import $(date)"

# Ensure this script is NOT run as root
if [ "$(id -u)" = "0" ]; then
    echo "#	This script must not be be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

# Lock directory
lockdir=/var/lock/cyclestreets
mkdir -p $lockdir

# Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 9 || { echo '#	An import is already running' ; exit 1; }

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

# Configure MySQL for import
if [ -n "${import_key_buffer_size}" ]; then
    echo "#	Configuring MySQL for import"
    mysql -hlocalhost -uroot -p${mysqlRootPassword} -e "set global key_buffer_size = ${import_key_buffer_size};";
fi
# These two variable changes affect new connections to the server and so can't be checked straight away with select @@...
if [ -n "${import_max_heap_table_size}" ]; then
    mysql -hlocalhost -uroot -p${mysqlRootPassword} -e "set global max_heap_table_size = ${import_max_heap_table_size};";
fi
if [ -n "${import_tmp_table_size}" ]; then
    mysql -hlocalhost -uroot -p${mysqlRootPassword} -e "set global tmp_table_size = ${import_tmp_table_size};";
fi

# Stop the routing service - if it is installed
if [ -e /etc/init.d/cycleroutingd ]; then

    # Note: the service command is available to the root user on debian
    # It is not possible to specify a null password prompt for sudo, hence the long explanatory prompt in place.
    echo $password | sudo -Sk -p"[sudo] Password for %p (No need to enter - it is provided by the script. This prompt should be ignored.)" /etc/init.d/cycleroutingd stop
fi

#       Move to the right place
cd ${importContentFolder}

#       Start the import (which sets a file lock called /var/lock/cyclestreets/importInProgress to stop multiple imports running)
php run.php

echo "# $(date)	CycleStreets import completed."
echo "# Run useNewImport script if import and live are on the same server."

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
