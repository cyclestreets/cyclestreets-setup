#!/bin/bash
# Script to change CycleStreets routing edition
#
# Run as the cyclestreets user (a check is peformed after the config file is loaded).
usage()
{
    cat << EOF
SYNOPSIS
	$0 -h -f [newEdition]

OPTIONS
	-h Show this message
	-f Force restart if the newEdition is already being served.

DESCRIPTION
	newEdition
		Names a routing database of the form routingYYMMDD, eg. routing151205
		Defaults to the latest version avaialble.
EOF
}

# Flag: Leave empty to avoid restarting if already serving the requested edition
forceRestart=

# http://wiki.bash-hackers.org/howto/getopts_tutorial
# See install-routing-data for best example of using this
while getopts "hf" option ; do
    case ${option} in
        h) usage; exit ;;
        f)
	    # Force a restart when edition unchanged
	    forceRestart=1
	    ;;
	\?) echo "Invalid option: -$OPTARG" >&2 ; exit ;;
    esac
done

# After getopts is done, shift all processed options away with
shift $((OPTIND-1))


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


### DEFAULTS ###

# An alternative machine that can provide routing services, especially during switch-routing-edition, should be full url including port, e.g. http://imports.cyclestreets.net:9000/
# If a fallbackRoutingUrl is specified, it must already be serving routes for the new edition.
fallbackRoutingUrl=


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
    echo "# The config file, ${configFile}, does not exist or is not executable - copy your own based on the ${configFile}.template file." 1>&2
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

# Local routing server
localRoutingUrl=http://localhost:9000/

# Check a local routing server is configured
if [ -z "${localRoutingUrl}" ]; then
	echo "#	The local routing service is not specified."
	exit 1
fi

# Useful binding
# The defaults-extra-file is a positional argument which must come first.
superMysql="mysql --defaults-extra-file=${mySuperCredFile} -hlocalhost"

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
getRoutingEditionXML="<?xml version=\"1.0\" encoding=\"utf-8\"?><methodCall><methodName>get_routing_edition</methodName></methodCall>"

# Cycle routing restart command (should match passwordless sudo entry)
routingServiceRestart="/bin/systemctl restart cyclestreets"

# Check the local routing service.
# The status check produces an error if it is not running, so temporarily
# turn off abandon-on-error to catch and report the problem.
set +e

# Note: use a path to check the status, rather than service which needs sudo
localRoutingStatus=$(cat ${websitesLogsFolder}/pythonAstarPort9000_status.log)
if [[ ! "$localRoutingStatus" =~ serving ]]
then
  echo "#	Note: there is no current routing service. Switchover will proceed."
else

    # Check not already serving this edition
    echo "#	Checking current edition on: ${localRoutingUrl}"

    # POST the request to the server
    currentRoutingEdition=$(curl -s -X POST -d "${getRoutingEditionXML}" ${localRoutingUrl} | xpath -q -e '/methodResponse/params/param/value/string/text()')

    # Check empty response
    if [ -z "${currentRoutingEdition}" ]; then
	echo "#	The current edition at ${localRoutingUrl} could not be determined."
	exit 1
    fi

    # Check if the newEdition is already being served
    if [ "${newEdition}" == "${currentRoutingEdition}" ]; then
	echo "#	The proposed edition: ${newEdition} is already being served from ${localRoutingUrl}"

	# Abandon unless a restart is forced
	if [ -z "${forceRestart}" ]; then
	    echo "#	Force a restart by setting the -f option, or using: sudo /bin/systemctl restart cyclestreets"
	    exit 0
	fi
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

## Multiple editions - result will be yes or no
multipleEditions=$(${superMysql} -s cyclestreets<<<"select multipleEditions from map_config where id = 1;")
if [ "${multipleEditions}" = yes ]; then

    # Turn off multiple editions for the switchover
    ${superMysql} cyclestreets -e "update map_config set multipleEditions='no';";

    # With multiple editions turned off the map_edition table is not read, and so can be prepared for the new state
    ${superMysql} cyclestreets -e "update map_edition set active = 'no'  where ordering > 1;";
    ${superMysql} cyclestreets -e "update map_edition set active = 'yes' where name = '${newEdition}';";
fi

### Do switch-over

# Clear this cache - (whose rows relate to a specific routing edition)
${superMysql} cyclestreets -e "truncate map_nearestPointCache;";

# If a fallbackRoutingUrl is supplied, check it is running and using the proposed edition
if [ -n "${fallbackRoutingUrl}" ]; then

    # POST the request to the server
    fallbackRoutingEdition=$(curl -s -X POST -d "${getRoutingEditionXML}" ${fallbackRoutingUrl} | xpath -q -e '/methodResponse/params/param/value/string/text()')

    # Check the fallback routing edition is the same as the proposed edition
    if [ "${newEdition}" != "${fallbackRoutingEdition}" ]; then
	echo "#	The fallback server is running: ${fallbackRoutingEdition} which differs from the proposed edition: ${newEdition}"
	exit 1
    fi

    # Use the fallback server during switch over
    ${superMysql} cyclestreets -e "update map_config set routingDb = '${newEdition}', routeServerUrl = '${fallbackRoutingUrl}' where id = 1;";
    echo "#	Now using fallback routing service"
else

    # Close the journey planner
    ${superMysql} cyclestreets -e "call closeJourneyPlanner();";
    echo "#	As there is no fallback routing server the journey planner service has been closed for the duration of the switch over."
fi


## Configure the routing engine to use the new edition

# Remove any old deprecated shell-style configuration
routingEngineConfigFile=${websitesContentFolder}/routingengine/.config.sh
rm -f $routingEngineConfigFile

# Remove any old JSON configuration
jsonConfig=${websitesContentFolder}/routingengine/.config.json
rm -f $jsonConfig

# Configure the routing engine to use the new edition
jsonRoutingConfig=${websitesContentFolder}/data/routing/${newEdition}/.config.json
if [ -r "${jsonRoutingConfig}" ]; then
    ln -s ${jsonRoutingConfig} $jsonConfig
else
    # Use deprecated shell-style config file
    echo -e "#!/bin/bash\nBASEDIR=${websitesContentFolder}/data/routing/${newEdition}" > $routingEngineConfigFile
    chmod a+x $routingEngineConfigFile
fi


# Remove routing data caches
rm -f ${websitesContentFolder}/data/tempgenerated/*.ridingSurfaceCache.php
rm -f ${websitesContentFolder}/data/tempgenerated/*.routingFactorCache.php

# Restart the routing service
sudo ${routingServiceRestart}

# Check the local routing service is currently serving (if it is not it will generate an error forcing this script to stop)
localRoutingStatus=$(cat ${websitesLogsFolder}/pythonAstarPort9000_status.log)

echo "#	Initial status: ${localRoutingStatus}"

# Wait until it has restarted
# !! This can loop forever - perhaps because in some situations (e.g a small test dataset) the start has been very quick.
while [[ ! "$localRoutingStatus" =~ serving ]]; do
    sleep 12
    localRoutingStatus=$(cat ${websitesLogsFolder}/pythonAstarPort9000_status.log)
    echo "#	Status: ${localRoutingStatus}"
done

# Get the locally running service
locallyRunningEdition=$(curl -s -X POST -d "${getRoutingEditionXML}" ${localRoutingUrl} | xpath -q -e '/methodResponse/params/param/value/string/text()')

# Check the local service is as requested
if [ "${locallyRunningEdition}" != "${newEdition}" ]; then
	echo "#	The local server is running: ${locallyRunningEdition} not the requested edition: ${newEdition}"
	exit 1
fi

# Switch the website to the local server and ensure the routingDb is also set
${superMysql} cyclestreets -e "update map_config set routingDb = '${newEdition}', routeServerUrl = '${localRoutingUrl}' where id = 1;";

# Restore the multiple editions state
${superMysql} cyclestreets -e "update map_config set multipleEditions='${multipleEditions}';";

# Re-open the journey planner
${superMysql} cyclestreets -e "call openJourneyPlanner();";


### Finishing

# Tinkle the update - the account with userId = 2 is a general notification account so that message appears to come from CycleStreets
formattedDate=`date -d "20${importDate}" "+%-d %B %Y"`
${superMysql} cyclestreets -e "insert tinkle (userId, tinkle) values (2, 'Routing data updated to ${formattedDate}, details: http://cycle.st/journey/help/osmconversion/');";

# Report
echo "#	$(date)	Completed switch to $newEdition"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
