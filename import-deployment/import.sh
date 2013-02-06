#!/bin/bash
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



# Get free disk space in Gigabytes
# http://www.cyberciti.biz/tips/shell-script-to-watch-the-disk-space.html
# !! Note: this check is rather machine-specific as it happens that on our machine the key disk is at /dev/sda1 which will not be true in general.
freeSpace=$(df -BG /dev/sda1 | grep -vE '^Filesystem' | awk '{ print $4 }')

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

#       Move to the right place
cd ${websitesContentFolder}

#       Start the import (which sets a file lock called /var/lock/cyclestreets/importInProgress to stop multiple imports running)
php import/run.php

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
