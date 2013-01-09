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

# Check the local routing service is currently serving (if it is not it will generate an error forcing this script to stop)
localRoutingStatus=$(/etc/init.d/cycleroutingd status)

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

# Check the format is routingYYMMDD
if [[ ! $importEdition =~ routing[0-9]{6} ]]; then
  echo "#	Arg importedition must specify a database of the form routingYYMMDD"
  exit 1
fi


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
    # apt-get -y install curl libxml-xpath-perl

    # XML for the calls to get the routing edition
    xmlrpccall="<?xml version=\"1.0\" encoding=\"utf-8\"?><methodCall><methodName>get_routing_edition</methodName></methodCall>"

    # Get the locally running service
    locallyRunningEdition=$(curl -s -X POST -d "${xmlrpccall}" http://localhost:9000/ | xpath -q -e '/methodResponse/params/param/value/string/text()')

    # POST the request to the server
    failoverRoutingEdition=$(curl -s -X POST -d "${xmlrpccall}" ${failoverRoutingServer} | xpath -q -e '/methodResponse/params/param/value/string/text()')

    # Check the failover routing edition is the same
    if [ ${locallyRunningEdition} != ${failoverRoutingEdition} ]; then
	echo "#	The failover server is running: ${failoverRoutingEdition} which differs from the local edition: ${locallyRunningEdition}"
# !! Ignore this while developping
#	exit 1
    fi
fi



### Stage 4 - do switch-over

# Use the failover server during switch over
if [ -n "${failoverRoutingServer}" ]; then

    # Switch the website to the new routing database
    mysql cyclestreets -hlocalhost -uroot -p${mysqlRootPassword} -e "UPDATE map_config SET routeServerUrl = '${failoverRoutingServer}' WHERE id = 1;";
    echo "#	Now using failover routing service"
else
    # When there is no failover server put the site into maintenance mode
    sudo -u $username touch ${websitesContentFolder}/maintenance
    echo "#	As there is no failover routing server the local site has entered maintenance mode"
fi

# Configure the routing engine to use the new edition
routingEngineConfigFile=/websites/www/content/routingengine/.config.sh
echo -e "#!/bin/bash\nBASEDIR=/websites/www/content/data/routing/${importEdition}" > $routingEngineConfigFile

# Ensure it is executable
chmod a+x $routingEngineConfigFile

# Restart the routing service
service cycleroutingd restart

# Check the local routing service is currently serving (if it is not it will generate an error forcing this script to stop)
localRoutingStatus=$(/etc/init.d/cycleroutingd status | grep "State:")
echo "#	Initial status: ${localRoutingStatus}"

# Wait until it has started
while [[ ! $localRoutingStatus =~ serving ]]; do
    sleep 10
    localRoutingStatus=$(/etc/init.d/cycleroutingd status | grep "State:")
    echo "#	Status: ${localRoutingStatus}"
done

# Get the locally running service
locallyRunningEdition=$(curl -s -X POST -d "${xmlrpccall}" http://localhost:9000/ | xpath -q -e '/methodResponse/params/param/value/string/text()')

# Check the local service is as requested
if [ ${locallyRunningEdition} != ${importEdition} ]; then
	echo "#	The local server is running: ${locallyRunningEdition} not the requested edition: ${importEdition}"
	exit 1
fi

# Switch the website to the new routing database
mysql cyclestreets -hlocalhost -uroot -p${mysqlRootPassword} -e "UPDATE map_config SET routingDb = '${importEdition}', routeServerUrl = 'http://localhost:9000/' WHERE id = 1;";

# Restore the site by switching off maintenance mode (-f ignores if non existent)
rm -f ${websitesContentFolder}/maintenance


### Stage 5 - end

# Finish
echo "#	All done"

# Remove the lock file
) 9>/var/lock/cyclestreetsimport

# End of file
