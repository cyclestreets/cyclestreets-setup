#!/bin/bash
# Script to switch the routing service to the newly generated import.
# Run after an import has completed, when the import and live service run from the same machine.
#
# Run as the cyclestreets user (a check is peformed after the config file is loaded).

echo "# $(date)	Use new CycleStreets import routing edition"

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


## Main body of script

# Ensure this script is run as cyclestreets user
if [ ! "$(id -nu)" = "${username}" ]; then
    echo "#	This script must be run as user ${username}, rather than as $(id -nu)." 1>&2
    exit 1
fi

# Check that the import finished correctly
if ! mysql -hlocalhost -uroot -p${mysqlRootPassword} --batch --skip-column-names -e "call importStatus()" cyclestreets | grep "valid\|cellOptimised" > /dev/null 2>&1
then
    echo "# The import process did not complete. The routing service will not be started."
    exit 1
fi

# Clear this cache - (whose rows relate to a specific routing edition)
mysql cyclestreets -hlocalhost -uroot -p${mysqlRootPassword} -e "truncate map_nearestPointCache;";


# Configure MySQL for routing
# During an import run these parameters may have been set to much larger values in order to process large data tables.
# Setting these parameters here will have the effect of reducing them from their import settings, at least until the next MySQL restart, when they will inherit the configuration values.
if [ -n "${routing_key_buffer_size}" ]; then
    echo "#	Configuring MySQL for serving routes"
    mysql -hlocalhost -uroot -p${mysqlRootPassword} -e "set global key_buffer_size = ${routing_key_buffer_size};";
fi
if [ -n "${routing_max_heap_table_size}" ]; then
    mysql -hlocalhost -uroot -p${mysqlRootPassword} -e "set global max_heap_table_size = ${routing_max_heap_table_size};";
fi
if [ -n "${routing_tmp_table_size}" ]; then
    mysql -hlocalhost -uroot -p${mysqlRootPassword} -e "set global tmp_table_size = ${routing_tmp_table_size};";
fi

echo "# Now starting the routing service for the new import"

# Start the routing service (the cyclestreets user should have passwordless sudo access to this command)
sudo /etc/init.d/cycleroutingd start

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
