#!/bin/bash
# Script to change CycleStreets daily editions
#
# Run as the cyclestreets user (a check is peformed after the config file is loaded).
usage()
{
    cat << EOF
SYNOPSIS
	$0 -h -k [freshEdition]

OPTIONS
	-h Show this message
	-k Keep the stale edition.

DESCRIPTION
	This script switches route serving from a STALE edition to a FRESH edition, which is assumed to be the newest installed edition.
	The freshEdition can be provided as an argument, if not then the newest non-active edition is selected.
	These editions are served from ports 8998 and 8999.
	Unless the -k option is set the stale edition is removed.
EOF
}

# Set to keep the stale edition (default is empty)
keepStale=

# http://wiki.bash-hackers.org/howto/getopts_tutorial
# See install-routing-data for best example of using this
while getopts ":hk" option ; do
    case ${option} in
        h) usage; exit ;;
	# Keep the stale edition
	k)
	    keepStale=1
	   ;;
	\?) echo "Invalid option: -$OPTARG" >&2 ; exit 1 ;;
    esac
done

# After getopts is done, shift all processed options away with
shift $((OPTIND-1))

### Stage 1 - general setup

# Announce start
echo "#	$(date)	CycleStreets daily routing edition switchover"

# Ensure this script is NOT run as root (it should be run as the cyclestreets user, having sudo rights as setup by install-website)
if [ "$(id -u)" = "0" ]; then
    echo "#	This script must NOT be run as root." 1>&2
    exit 1
fi

# Set the script to exit when an error occurs
set -e

# Lock directory
lockdir=/var/lock/cyclestreets
mkdir -p $lockdir

# Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 9 || { echo '#	A daily routing switchover is already running' ; exit 1; }

### CREDENTIALS ###

# Define the location of the credentials file; see: http://stackoverflow.com/a/246128/180733
# A more advanced technique will be required if this file is called via a symlink.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Use this to remove the ../
ScriptHome=$(readlink -f "${DIR}/..")

# Change to the script's folder
cd ${ScriptHome}

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

# Useful binding
# The defaults-extra-file is a positional argument which must come first.
superMysql="mysql --defaults-extra-file=${mySuperCredFile} -hlocalhost"

# Check using multiple editions #multipleEditions
multipleEditions=$(${superMysql} -s cyclestreets<<<"select multipleEditions from map_config where id = 1 limit 1;")
if [ ! "${multipleEditions}" == "yes" ]; then
	echo "# Abandoning: this script only works with multiple routing editions."
	exit 1
fi

# Check the supplied argument - if exactly one use it, else default to latest routing db
if [ $# -eq 1 ]
then
    # Allocate that argument
    freshEdition=$1
else

    # Determine latest edition (the -s suppresses the tabular output)
    freshEdition=$(${superMysql} -s cyclestreets<<<"select routingDb from map_edition order by routingDb desc limit 1;")
fi

# Check the format is routingYYMMDD
if [[ ! "$freshEdition" =~ routing([0-9]{6}) ]]; then
  echo "#	The supplied argument must specify a routing edition of the form routingYYMMDD, but this was received: ${freshEdition}."
  exit 1
fi

# Ensure the latest edition has ordering 1 - which is used to distinguish the daily editions from other editions.
${superMysql} cyclestreets -e "update map_edition set ordering = 1 where routingDb = '${freshEdition}';";

# Determine the stale edition
staleEdition=$(${superMysql} -s cyclestreets<<<"select routingDb from map_edition where ordering = 1 and active = 'yes' order by routingDb desc limit 1;")

# Abandon if no stale edition
if [ -z "${staleEdition}" ]; then
	echo "#	There is no stale edition: ${staleEdition}, so abandoning."
	exit 1
fi

# Abandon if the two are the same
if [ "${freshEdition}" == "${staleEdition}" ]; then
	echo "#	The proposed edition: ${freshEdition} is the same as already running: ${staleEdition}, so abandoning"
	exit 1
fi

# Determine the port of the stale edition
stalePort=$(${superMysql} -s cyclestreets<<<"select substring(regexp_substr(url, ':[0-9]+'), 2) port from map_edition where routingDb = '${staleEdition}';")

# Abandon if no stale port
if [ -z "${stalePort}" ]; then
	echo "#	There is no stale port: ${stalePort}, so abandoning."
	exit 1
fi

# Choose ports
if [ "${stalePort}" == "8998" ]; then
	freshPort=8999
else
	freshPort=8998
	stalePort=8999
fi

### Confirm existence of the routing import database and files

# Check to see that this routing database exists
if ! ${superMysql} -e "use ${freshEdition}"; then
	echo "#	The fresh routing database ${freshEdition} is not present"
	exit 1
fi

# Check that the data for this routing edition exists
if [ ! -d "${websitesContentFolder}/data/routing/${freshEdition}" ]; then
	echo "#	The fresh routing data ${freshEdition} is not present"
	exit 1
fi

# Check that the installation completed
if [ ! -e "${websitesContentFolder}/data/routing/${freshEdition}/installationCompleted.txt" ]; then
	echo "#	Switching cannot continue because the routing installation did not appear to complete."
	exit 1
fi

# Announce planned changes
echo "#	Planning to switch to fresh edition: ${freshEdition} port ${freshPort} from stale edition: ${staleEdition} port ${stalePort}."


### Do switch-over

# Clear this cache - (whose rows relate to a specific routing edition)
${superMysql} cyclestreets -e "truncate map_nearestPointCache;";

# Remove routing data caches
rm -f ${websitesContentFolder}/data/tempgenerated/*.ridingSurfaceCache.php
rm -f ${websitesContentFolder}/data/tempgenerated/*.routingFactorCache.php

# Remove old JSON configuration
freshServiceJsonConfig=${websitesContentFolder}/routingengine/.config.${freshPort}.json
rm -f $freshServiceJsonConfig

# Configure the fresh routing service to use the new edition
freshJsonConfig=${websitesContentFolder}/data/routing/${freshEdition}/.config.json
if [ -r "${freshJsonConfig}" ]; then
    ln -s ${freshJsonConfig} $freshServiceJsonConfig
else
    # Error
    echo "#	The fresh routing configuration file is absent: ${freshJsonConfig}"
    exit 1
fi

# Bind service names
freshService=cyclestreets@${freshPort}
staleService=cyclestreets@${stalePort}

# Routing service commands (using command that matches pattern setup in passwordless sudo)
freshRoutingServiceRestart="/bin/systemctl restart ${freshService}"
staleRoutingServiceStop="/bin/systemctl stop ${staleService}"

# Restart the routing service
sudo ${freshRoutingServiceRestart}

# Check the status
freshStatusLog=${websitesLogsFolder}/pythonAstarPort${freshPort}_status.log
freshRoutingStatus=$(cat ${freshStatusLog})
echo "#	Initial status: ${freshRoutingStatus}"

# Wait until it has restarted
# !! This can loop forever - perhaps because in some situations (e.g a small test dataset) the start has been very quick.
while [[ ! "$freshRoutingStatus" =~ serving ]]; do
	# The sleep is an attempt to avoid the loop forever
    sleep 2
    freshRoutingStatus=$(cat ${freshStatusLog})
    echo "#	Status: ${freshRoutingStatus}"
done

# XML for the calls to get the routing edition
getRoutingEditionXML="<?xml version=\"1.0\" encoding=\"utf-8\"?><methodCall><methodName>get_routing_edition</methodName></methodCall>"

# Fresh routing server
freshRoutingUrl=http://localhost:${freshPort}/

# Check the local routing service.
# The status check produces an error if the service is not running, so temporarily
# turn off abandon-on-error to catch and report the problem.
set +e

# Get the locally running service
locallyRunningEdition=$(curl --connect-timeout 1 --silent --request POST --data "${getRoutingEditionXML}" ${freshRoutingUrl} | xpath -q -e '/methodResponse/params/param/value/string/text()')

# Restore abandon on error
set -e

# Check the local service is as requested
if [ "${locallyRunningEdition}" != "${freshEdition}" ]; then
	echo "#	The local fresh server is running: ${locallyRunningEdition} not the requested edition: ${freshEdition}"
	exit 1
fi

# Switch editions in the database
${superMysql} cyclestreets -e "call switchDailyEditions('${freshEdition}', '${freshRoutingUrl}', '${staleEdition}');";

# Stop the stale service
sudo ${staleRoutingServiceStop}


# Photos en route index
${superMysql} ${freshEdition} -e "call indexPhotos(0);";

# Remove the stale edition
if [ -z "${keepStale}" ]; then
    echo "#	$(date)	Stale edition ${staleEdition} will now be removed."
    live-deployment/remove-routing-edition.sh ${staleEdition}

	# Remove old JSON configuration
	staleServiceJsonConfig=${websitesContentFolder}/routingengine/.config.${stalePort}.json
	rm -f $staleServiceJsonConfig

else
    echo "#	$(date)	Previous edition ${staleEdition} is retained."
fi

### Finishing

# Report
echo "#	$(date)	Completed switch to $freshEdition"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
