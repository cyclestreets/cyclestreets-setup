#!/bin/bash
# Script to install CycleStreets routing data on Ubuntu
# Tested on 12.10 (View Ubuntu version using 'lsb_release -a')
# This script is idempotent - it can be safely re-run without destroying existing data



### Stage 1 - general setup

echo "#	CycleStreets routing data installation switching"

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#	This script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

# Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 9 || { echo 'An installation is already running' ; exit 1; }


### CREDENTIALS ###

# Define the location of the credentials file; see: http://stackoverflow.com/a/246128/180733
configFile=../.config.sh
SCRIPTDIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Generate your own credentials file by copying from .config.sh.template
if [ ! -e $SCRIPTDIRECTORY/${configFile} ]; then
    echo "# The config file, ${configFile}, does not exist - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. $SCRIPTDIRECTORY/${configFile}

# Logging
# Use an absolute path for the log file to be tolerant of the changing working directory in this script
setupLogFile=$(readlink -e $(dirname $0))/log.txt
touch ${setupLogFile}
echo "#	CycleStreets routing data switchover in progress, follow log file with: tail -f ${setupLogFile}"
echo "#	CycleStreets routing data switchover $(date)" >> ${setupLogFile}

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


### Stage 2 - ensure required parameters are present

# Ensure there is a single argument, defining the routing edition, or end
if [ $# -ne 1 ]
then
  echo "#	Usage: `basename $0` importedition"
  exit 1
fi

# Allocate that argument
importEdition=$1


### Stage 3 - confirm existence of the routing import database and files

# Check to see that this routing database exists
if ! mysql -hlocalhost -uroot -p${mysqlRootPassword} -e "use ${importEdition}"; then
	echo "#	The routing database ${importEdition} is not present"
	exit 1
fi

# Check to see that the routing data file for this routing edition exists
if [ ! -d "${websitesContentFolder}/data/routing/${importEdition}" ]; then
	echo "#	The routing data file ${importEdition} is not present"
	exit 1
fi

# Check if the failoverRoutingServer is running
if [ -n "${failoverRoutingServer}" ]; then

	# Required packages
	#sudo apt-get -y install curl libxml-xpath-perl

	# XML for the call
	xmlrpccall="<?xml version=\"1.0\" encoding=\"utf-8\"?><methodCall><methodName>get_routing_edition</methodName></methodCall>"

	# POST the request to the server
	failoverRoutingEdition=$(curl -s -X POST -d "${xmlrpccall}" ${failoverRoutingServer} | xpath -q -e '/methodResponse/params/param/value/string/text()')

	# Check the failover routing edition is the same
	if [ ${failoverRoutingEdition} != ${importEdition} ]; then
	    echo "#	The failover server is running ${failoverRoutingEdition} where locally ${importEdition} is running"
	    exit 1
	fi
fi

### Stage 4 - do switch-over

# Put the site into maintenance mode
sudo -u $username touch ${websitesContentFolder}/maintenance

# Stop the service if running
# !! Rather than clever stuff like this, strengthen the 'service cycleroutingd' options to start,stop or reload the routing system
ps cax | grep routing_server.py > /dev/null
if [ $? -eq 0 ]; then
	echo "#	Stopping current routing service"
	service cycleroutingd stop
fi

#!# Update the service config here

# Restarting the routing engine on the live CycleStreets machine can take around half-an-hour to complete.
# To avoid loss of service, routing is temporarily diverted to the backup machine to provide routes.

# Start the routing daemon (service)
service cycleroutingd start

#!# Needs to wait for confirmation that it is fully started, e.g. making a port 9000 GET request perhaps

# Switch the website to the new routing database
mysql cyclestreets -hlocalhost -uroot -p${mysqlWebsiteUsername} -e "UPDATE map_config SET routingDb = '${importEdition}' WHERE id = 1;";

# Restore the site by switching off maintenance mode
rm ${websitesContentFolder}/maintenance


### Stage 5 - end

# Finish
echo "#	All done"

# Remove the lock file
) 9>/var/lock/cyclestreetsimport

# End of file
