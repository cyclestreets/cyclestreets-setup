#!/bin/bash
# Script to change CycleStreets served routes
#
# Run as the cyclestreets user (a check is peformed after the config file is loaded).

# http://ubuntuforums.org/showthread.php?t=1783298
usage()
{
    cat << EOF
SYNOPSIS
	$0 -h [newEdition]

OPTIONS
	-h Show this message

DESCRIPTION
	newEdition
		Names a routing database of the form routingYYMMDD, eg. routing151205
		Defaults to the latest version avaialble.
EOF
}

# http://wiki.bash-hackers.org/howto/getopts_tutorial
# See install-routing-data for best example of using this
while getopts ":h" option ; do
    case ${option} in
        h) usage; exit ;;
	\?) echo "Invalid option: -$OPTARG" >&2 ; exit ;;
    esac
done

# This file is only geared towards updating the locally served routes to a new edition.
# Pre-requisites:
# If a fallbackRoutingServer is specified, it must already be serving routes for the new edition.

### Stage 1 - general setup

# Announce start
echo "#	$(date)	CycleStreets routing data switchover"

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


## Main body from here

# Ensure there is a cyclestreets user account
if [ ! id -u ${username} >/dev/null 2>&1 ]; then
	echo "# User ${username} must exist: please run the main website install script"
	exit 1
fi

# Ensure this script is run as cyclestreets user
if [ ! "$(id -nu)" = "${username}" ]; then
    echo "#	This script must be run as user ${username}, rather than as $(id -nu)." 1>&2
    exit 1
fi

# Ensure the main website installation is present
if [ ! -d ${websitesContentFolder}/data/routing -o ! -d $websitesBackupsFolder ]; then
	echo "# The main website installation must exist: please run the main website install script"
	exit 1
fi

# Ensure the routing daemon (service) is installed
if [ ! -f ${routingDaemonLocation} ]; then
	echo "#	The routing daemon (service) is not installed"
	exit 1
fi

# Check a local routing server is configured
if [ -z "${localRoutingUrl}" ]; then
	echo "#	The local routing service is not specified."
	exit 1
fi

# Check the supplied argument - if exactly one use it, else default to latest routing db
if [ $# -eq 1 ]
then

    # Allocate that argument
    newEdition=$1
else

    # Determine latest edition (the -s suppresses the tabular output)
    newEdition=$(${superMysql} -s cyclestreets<<<"SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME LIKE 'routing%' order by SCHEMA_NAME desc limit 1;")
fi

# Announce edition
echo "#	Planning to switch to edition: ${newEdition}"

# XML for the calls to get the routing edition
xmlrpccall="<?xml version=\"1.0\" encoding=\"utf-8\"?><methodCall><methodName>get_routing_edition</methodName></methodCall>"

# Check the local routing service.
# The status check produces an error if it is not running, so temporarily
# turn off abandon-on-error to catch and report the problem.
set +e

# Note: use a path to check the daemon, rather than service which is not available to non-root users on debian
localRoutingStatus=$(${routingDaemonLocation} status)
if [ $? -ne 0 ]
then
  echo "#	Note: there is no current routing service. Switchover will proceed."
else

    # Check not already serving this edition
    echo "#	Checking current edition on: ${localRoutingUrl}"

    # POST the request to the server
    currentRoutingEdition=$(curl -s -X POST -d "${xmlrpccall}" ${localRoutingUrl} | xpath -q -e '/methodResponse/params/param/value/string/text()')

    # Check empty response
    if [ -z "${currentRoutingEdition}" ]; then
	echo "#	The current edition at ${localRoutingUrl} could not be determined."
	exit 1
    fi

    # Check the fallback routing edition is the same as the proposed edition
    if [ "${newEdition}" == "${currentRoutingEdition}" ]; then
	echo "#	The proposed edition: ${newEdition} is already being served from ${localRoutingUrl}"
	echo "#	Restart it using: sudo /bin/systemctl restart cycleroutingd"
	echo "#	Routing restart will be attempted:"
	sudo /bin/systemctl restart cycleroutingd
	echo "#	Routing service has restarted"

	# Clean exit
	exit 0
    fi

    # Report edition
    echo "#	Current edition: ${currentRoutingEdition}"
fi

# Restore abandon-on-error
set -e

# Check the format is routingYYMMDD
if [[ ! "$newEdition" =~ routing([0-9]{6}) ]]; then
  echo "#	The supplied argument must specify a routing edition of the form routingYYMMDD, but this was received: ${newEdition}."
  exit 1
fi

# Extract the date part of the routing database
importDate=${BASH_REMATCH[1]}

### Confirm existence of the routing import database and files

# Check to see that this routing database exists
if ! ${superMysql} -e "use ${newEdition}"; then
	echo "#	The routing database ${newEdition} is not present"
	exit 1
fi

# Check that the data for this routing edition exists
if [ ! -d "${websitesContentFolder}/data/routing/${newEdition}" ]; then
	echo "#	The routing data ${newEdition} is not present"
	exit 1
fi

# Check that the installation completed
if [ ! -e "${websitesContentFolder}/data/routing/${newEdition}/installationCompleted.txt" ]; then
	echo "#	Switching cannot continue because the routing installation did not appear to complete."
	exit 1
fi

### Do switch-over

# Clear this cache - (whose rows relate to a specific routing edition)
${superMysql} cyclestreets -e "truncate map_nearestPointCache;";

# If a fallbackRoutingServer is supplied, check it is running and using the proposed edition
if [ -n "${fallbackRoutingServer}" ]; then

    # POST the request to the server
    fallbackRoutingEdition=$(curl -s -X POST -d "${xmlrpccall}" ${fallbackRoutingServer} | xpath -q -e '/methodResponse/params/param/value/string/text()')

    # Check the fallback routing edition is the same as the proposed edition
    if [ "${newEdition}" != "${fallbackRoutingEdition}" ]; then
	echo "#	The fallback server is running: ${fallbackRoutingEdition} which differs from the proposed edition: ${newEdition}"
	exit 1
    fi

    # Use the fallback server during switch over
    ${superMysql} cyclestreets -e "UPDATE map_config SET routingDb = '${newEdition}', routeServerUrl = '${fallbackRoutingServer}' WHERE id = 1;";
    echo "#	Now using fallback routing service"
else

    # Set the journeyPlannerStatus to closed for the duration
    ${superMysql} cyclestreets -e "UPDATE map_config SET journeyPlannerStatus = 'closed' WHERE id = 1;";
    echo "#	As there is no fallback routing server the journey planner service has been closed for the duration of the switch over."
fi

# Configure the routing engine to use the new edition
echo -e "#!/bin/bash\nBASEDIR=${websitesContentFolder}/data/routing/${newEdition}" > $routingEngineConfigFile

# Ensure it is executable
chmod a+x $routingEngineConfigFile

# Restart the routing service
# Rather than use the restart option to the service, it is stopped then started. This enables the script to verify that the service did stop properly in between.
# This seems to be necessary when there are large amounts of memory being freed by stopping.

# Stop the routing service (the cyclestreets user should have passwordless sudo access to this command)
sudo ${routingDaemonStop}

# Check the local routing service has stopped
localRoutingStatus=$(${routingDaemonLocation} status | grep "State:")
echo "#	Initial status: ${localRoutingStatus}"

# Wait until it has stopped
while [[ ! "$localRoutingStatus" =~ stopped ]]; do
    sleep 10
    localRoutingStatus=$(${routingDaemonLocation} status | grep "State:")
    echo "#	Status: ${localRoutingStatus}"
done

# Start
sudo ${routingDaemonStart}


# Check the local routing service is currently serving (if it is not it will generate an error forcing this script to stop)
localRoutingStatus=$(${routingDaemonLocation} status | grep "State:")
echo "#	Initial status: ${localRoutingStatus}"

# Wait until it has restarted
# !! This can loop forever - perhaps because in some situations (e.g a small test dataset) the start has been very quick.
while [[ ! "$localRoutingStatus" =~ serving ]]; do
    sleep 10
    localRoutingStatus=$(${routingDaemonLocation} status | grep "State:")
    echo "#	Status: ${localRoutingStatus}"
done

# Get the locally running service
locallyRunningEdition=$(curl -s -X POST -d "${xmlrpccall}" ${localRoutingUrl} | xpath -q -e '/methodResponse/params/param/value/string/text()')

# Check the local service is as requested
if [ "${locallyRunningEdition}" != "${newEdition}" ]; then
	echo "#	The local server is running: ${locallyRunningEdition} not the requested edition: ${newEdition}"
	exit 1
fi

# Switch the website to the local server and ensure the routingDb is also set
${superMysql} cyclestreets -e "UPDATE map_config SET routingDb = '${newEdition}', routeServerUrl = '${localRoutingUrl}' WHERE id = 1;";

# Restore the journeyPlannerStatus
${superMysql} cyclestreets -e "UPDATE map_config SET journeyPlannerStatus = 'live' WHERE id = 1;";


### Finishing

# Tinkle the update - the account with userId = 2 is a general notification account so that message appears to come from CycleStreets
formattedDate=`date -d "20${importDate}" "+%-d %B %Y"`
${superMysql} cyclestreets -e "insert tinkle (userId, tinkle) values (2, 'Routing data updated to ${formattedDate}, details: http://cycle.st/journey/help/osmconversion/');";

# Report
echo "#	$(date)	Completed switch to $newEdition"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
