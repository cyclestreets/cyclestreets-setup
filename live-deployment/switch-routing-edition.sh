#!/bin/bash
# Script to change CycleStreets served routes
# Tested on Ubuntu 12.10 & Debian Squeeze (View Ubuntu version using 'lsb_release -a')
# This script is idempotent - it can be safely re-run without destroying existing data

# SYNOPSIS
#	run.sh newEdition
#
# DESCRIPTION
#	newEdition
#		Names a routing database of the form routingYYMMDD, eg. routing130111

# This file is only geared towards updating the locally served routes to a new edition.
# Pre-requisites:
# The local server must be currently serving routes - this script cannot be used to start a routing service.
# If a failOverServer is specified, it must already be serving routes for the new edition.

### Stage 1 - general setup

echo "#	CycleStreets switch routing edition"

# Ensure this script is NOT run as root (it should be run as the cyclestreets user, having sudo rights as setup by install-website)
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
	flock -n 9 || { echo '#	A switchover is already running' ; exit 1; }

### CREDENTIALS ###

# Define the location of the credentials file; see: http://stackoverflow.com/a/246128/180733
# A more advanced technique will be required if this file is called via a symlink.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Use this to remove the ../
ScriptHome=$(readlink -f "${DIR}/..")

# Name of the credentials file
configFile=${ScriptHome}/.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x ${configFile} ]; then
    echo "# The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. ${configFile}

# Logging
# Use an absolute path for the log file to be tolerant of the changing working directory in this script
setupLogFile=$(readlink -e $(dirname $0))/log.txt
touch ${setupLogFile}
echo "#	CycleStreets routing data switchover in progress, follow log file with: tail -f ${setupLogFile}"
echo "$(date)	CycleStreets routing data switchover" >> ${setupLogFile}

# Ensure there is a cyclestreets user account
if [ ! id -u ${username} >/dev/null 2>&1 ]; then
	echo "# User ${username} must exist: please run the main website install script"
	exit 1
fi

# Ensure the main website installation is present
if [ ! -d ${websitesContentFolder}/data/routing -o ! -d $websitesBackupsFolder ]; then
	echo "# The main website installation must exist: please run the main website install script"
	exit 1
fi

# Ensure the routing daemon (service) is installed
if [ ! -f /etc/init.d/cycleroutingd ]; then
	echo "#	The routing daemon (service) is not installed"
	exit 1
fi

# Check the local routing service is currently serving
# The status check produces an error if it is not running, so briefly turn off abandon-on-error to catch and report the problem.
set +e
# Note: we must use /etc/init.d path to the demon, rather than service which is not available to non-root users on debian
localRoutingStatus=$(/etc/init.d/cycleroutingd status)
if [ $? -ne 0 ]
then
  echo "#	Switchover expects the routing service to be running."
  exit 1
fi
# Restore abandon-on-error
set -e

### Stage 2 - ensure required parameters are present

# Ensure there is a single argument, defining the routing edition, or end
if [ $# -ne 1 ]
then
  echo "#	Usage: `basename $0` importedition"
  exit 1
fi

# Allocate that argument
newEdition=$1

# Check the format is routingYYMMDD
if [[ ! "$newEdition" =~ routing[0-9]{6} ]]; then
  echo "#	Arg importedition must specify a database of the form routingYYMMDD"
  exit 1
fi


### Stage 3 - confirm existence of the routing import database and files

# Check to see that this routing database exists
if ! mysql -hlocalhost -uroot -p${mysqlRootPassword} -e "use ${newEdition}"; then
	echo "#	The routing database ${newEdition} is not present"
	exit 1
fi

# Check that the data for this routing edition exists
if [ ! -d "${websitesContentFolder}/data/routing/${newEdition}" ]; then
	echo "#	The routing data ${newEdition} is not present"
	exit 1
fi

### Stage 4 - do switch-over

# XML for the calls to get the routing edition
xmlrpccall="<?xml version=\"1.0\" encoding=\"utf-8\"?><methodCall><methodName>get_routing_edition</methodName></methodCall>"

# If a failoverRoutingServer is supplied, check it is running and using the proposed edition
if [ -n "${failoverRoutingServer}" ]; then

    # Required packages
    # echo $password | sudo -Sk apt-get -y install curl libxml-xpath-perl

    # POST the request to the server
    failoverRoutingEdition=$(curl -s -X POST -d "${xmlrpccall}" ${failoverRoutingServer} | xpath -q -e '/methodResponse/params/param/value/string/text()')

    # Check the failover routing edition is the same as the proposed edition
    if [ "${newEdition}" != "${failoverRoutingEdition}" ]; then
	echo "#	The failover server is running: ${failoverRoutingEdition} which differs from the proposed edition: ${newEdition}"
	exit 1
    fi

    # Use the failover server during switch over
    mysql cyclestreets -hlocalhost -uroot -p${mysqlRootPassword} -e "UPDATE map_config SET routingDb = '${newEdition}', routeServerUrl = '${failoverRoutingServer}' WHERE id = 1;";
    echo "#	Now using failover routing service"
else
    # When there is no failover server put the site into maintenance mode
    sudo -u $username touch ${websitesContentFolder}/maintenance
    echo "#	As there is no failover routing server the local site has entered maintenance mode"
fi

# Configure the routing engine to use the new edition
routingEngineConfigFile=${websitesContentFolder}/routingengine/.config.sh
echo -e "#!/bin/bash\nBASEDIR=${websitesContentFolder}/data/routing/${newEdition}" > $routingEngineConfigFile

# Ensure it is executable
chmod a+x $routingEngineConfigFile

# Restart the routing service
# Rather than use the restart option to the service, it is stopped then started. This enables the script to verify that the service did stop properly in between.
# This seems to be necessary when there are large amounts of memory being freed by stopping.

# Note: the service command is available to the root user on debian
# Stop
# It is not possible to specify a null password prompt for sudo, hence the long explanatory prompt in place.
echo $password | sudo -Sk -p"[sudo] Password for %p (No need to enter - it is provided by the script. This prompt should be ignored.)" service cycleroutingd stop

# Check the local routing service has stopped
localRoutingStatus=$(/etc/init.d/cycleroutingd status | grep "State:")
echo "#	Initial status: ${localRoutingStatus}"

# Wait until it has stopped
while [[ ! "$localRoutingStatus" =~ stopped ]]; do
    sleep 10
    localRoutingStatus=$(/etc/init.d/cycleroutingd status | grep "State:")
    echo "#	Status: ${localRoutingStatus}"
done

# Start
echo $password | sudo -Sk service cycleroutingd start


# Check the local routing service is currently serving (if it is not it will generate an error forcing this script to stop)
localRoutingStatus=$(/etc/init.d/cycleroutingd status | grep "State:")
echo "#	Initial status: ${localRoutingStatus}"

# Wait until it has restarted
while [[ ! "$localRoutingStatus" =~ serving ]]; do
    sleep 10
    localRoutingStatus=$(/etc/init.d/cycleroutingd status | grep "State:")
    echo "#	Status: ${localRoutingStatus}"
done

# Get the locally running service
locallyRunningEdition=$(curl -s -X POST -d "${xmlrpccall}" ${localRoutingServer} | xpath -q -e '/methodResponse/params/param/value/string/text()')

# Check the local service is as requested
if [ "${locallyRunningEdition}" != "${newEdition}" ]; then
	echo "#	The local server is running: ${locallyRunningEdition} not the requested edition: ${newEdition}"
	exit 1
fi

# Switch the website to the local server and ensure the routingDb is also set
mysql cyclestreets -hlocalhost -uroot -p${mysqlRootPassword} -e "UPDATE map_config SET routingDb = '${newEdition}', routeServerUrl = '${localRoutingServer}' WHERE id = 1;";

# Restore the site by switching off maintenance mode (-f ignores if non existent)
rm -f ${websitesContentFolder}/maintenance


### Stage 5 - end

# Finish
echo "#	All done"
echo "$(date)	Completed switch to $newEdition" >> ${setupLogFile}

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
