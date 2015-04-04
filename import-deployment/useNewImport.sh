#!/bin/bash
# Script to switch the routing service to the newly generated import.
# Run after an import has completed, when the import and live service run from the same machine.

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

# The stuff below is really to do with switching to a new routing edition and could be considered as a separate task.

# Clear this cache - (whose rows relate to a specific routing edition)
mysql cyclestreets -hlocalhost -uroot -p${mysqlRootPassword} -e "truncate map_nearestPointCache;";

# Check that the import finished correctly
if ! mysql -hlocalhost -uroot -p${mysqlRootPassword} --batch --skip-column-names -e "call importStatus()" cyclestreets | grep "valid\|cellOptimised" > /dev/null 2>&1
then
    echo "# The import process did not complete. The routing service will not be started."
    exit 1
fi


# Configure MySQL for routing
# !! These values should only take effect until the next MySQL restart. The value they have here is to reduce sizes from the big import values down to runtime levels after an import.
# Therefore doing a MySQL restart is probably the smarter thing to do.
if [ -n "${routing_key_buffer_size}" ]; then
    echo "#	Configuring MySQL for serving routes"
    mysql cyclestreets -hlocalhost -uroot -p${mysqlRootPassword} -e "set global key_buffer_size = ${routing_key_buffer_size};";
fi
if [ -n "${routing_max_heap_table_size}" ]; then
    mysql cyclestreets -hlocalhost -uroot -p${mysqlRootPassword} -e "set global max_heap_table_size = ${routing_max_heap_table_size};";
fi
if [ -n "${routing_tmp_table_size}" ]; then
    mysql cyclestreets -hlocalhost -uroot -p${mysqlRootPassword} -e "set global tmp_table_size = ${routing_tmp_table_size};";
fi

echo "# Now starting the routing service for the new import"

# Start the routing service
# Note: the service command is available to the root user on debian
# It is not possible to specify a null password prompt for sudo, hence the long explanatory prompt in place.
echo $password | sudo -Sk -p"[sudo] Password for %p (No need to enter - it is provided by the script. This prompt should be ignored.)" /etc/init.d/cycleroutingd start

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
