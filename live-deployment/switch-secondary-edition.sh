#!/bin/bash
# Script to change CycleStreets secondary routing edition.
#
# Run as the cyclestreets user (a check is peformed after the config file is loaded).
usage()
{
    cat << EOF
SYNOPSIS
	$0 -h -k [edition]

OPTIONS
	-h Show this message
	-k Keep the previous secondary edition.

DESCRIPTION
	Switches the secondary routing edition to the optionally provided edition, which defaults to the latest edition.
	Unless the -k option is set the previous edition is removed.
	Secondary editions are assumed to be served from port 9001.
EOF
}

# Set to keep the old edition (default is empty)
keepOldOne=

# http://wiki.bash-hackers.org/howto/getopts_tutorial
# See install-routing-data for best example of using this
while getopts ":hk" option ; do
    case ${option} in
        h) usage; exit ;;
	# Keep the old edition
	k)
	    keepOldOne=1
	   ;;
	\?) echo "Invalid option: -$OPTARG" >&2 ; exit ;;
    esac
done

# After getopts is done, shift all processed options away with
shift $((OPTIND-1))

### Stage 1 - general setup

# Announce start
echo "#	$(date)	CycleStreets secondary routing switchover"

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
	flock -n 9 || { echo '#	A secondary switchover is already running' ; exit 1; }

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

# Local routing2 server
localRouting2Url=http://localhost:9001/

# Check a local routing server 2 is configured
if [ -z "${localRouting2Url}" ]; then
	echo "#	The local routing service 2 is not specified."
	exit 1
fi

# Useful binding
# The defaults-extra-file is a positional argument which must come first.
superMysql="mysql --defaults-extra-file=${mySuperCredFile} -hlocalhost"

# Check the supplied argument - if exactly one use it, else default to latest routing db
if [ $# -eq 1 ]
then

    # Allocate that argument
    newSecondaryEdition=$1
else

    # Determine latest edition (the -s suppresses the tabular output)
    newSecondaryEdition=$(${superMysql} -s cyclestreets<<<"SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME LIKE 'routing%' order by SCHEMA_NAME desc limit 1;")
fi

# Announce edition
echo "#	Planning to switch to secondary edition: ${newSecondaryEdition}"

# XML for the calls to get the routing edition
getRoutingEditionXML="<?xml version=\"1.0\" encoding=\"utf-8\"?><methodCall><methodName>get_routing_edition</methodName></methodCall>"

# Cycle routing2 restart command (using command that matches pattern setup in passwordless sudo)
routingService2Restart="/bin/systemctl restart cyclestreets2"

# Check the local routing service.
# The status check produces an error if it is not running, so temporarily
# turn off abandon-on-error to catch and report the problem.
set +e

# Note: use a path to check the status, rather than service which needs sudo
statusLog2=${websitesLogsFolder}/pythonAstarPort9001_status.log
localRouting2Status=$(cat ${statusLog2})
if [[ ! "$localRouting2Status" =~ serving ]]
then
  echo "#	Note: there is no current routing service. Switchover will proceed."
else

    # Check not already serving this edition
    echo "#	Checking current edition on: ${localRouting2Url}"

    # POST the request to the server
    currentSecondaryEdition=$(curl -s -X POST -d "${getRoutingEditionXML}" ${localRouting2Url} | xpath -q -e '/methodResponse/params/param/value/string/text()')

    # Check empty response
    if [ -z "${currentSecondaryEdition}" ]; then
	echo "#	The current edition at ${localRouting2Url} could not be determined."
	exit 1
    fi

    # Check the fallback routing edition is the same as the proposed edition
    if [ "${newSecondaryEdition}" == "${currentSecondaryEdition}" ]; then
	echo "#	The proposed edition: ${newSecondaryEdition} is already being served from ${localRouting2Url}"
	echo "#	Restart it using: sudo /bin/systemctl restart cyclestreets"
	echo "#	Routing restart 2 will be attempted:"
	sudo ${routingService2Restart}
	echo "#	Routing service 2 has restarted"

	# Clean exit
	exit 0
    fi

    # Report edition
    echo "#	Current secondary edition: ${currentSecondaryEdition}"
fi

# Restore abandon-on-error
set -e

# Check the format is routingYYMMDD
if [[ ! "$newSecondaryEdition" =~ routing([0-9]{6}) ]]; then
  echo "#	The supplied argument must specify a routing edition of the form routingYYMMDD, but this was received: ${newSecondaryEdition}."
  exit 1
fi

# Extract the date part of the routing database
importDate=${BASH_REMATCH[1]}

### Confirm existence of the routing import database and files

# Check to see that this routing database exists
if ! ${superMysql} -e "use ${newSecondaryEdition}"; then
	echo "#	The secondary routing database ${newSecondaryEdition} is not present"
	exit 1
fi

# Check that the data for this routing edition exists
if [ ! -d "${websitesContentFolder}/data/routing/${newSecondaryEdition}" ]; then
	echo "#	The secondary routing data ${newSecondaryEdition} is not present"
	exit 1
fi

# Check that the installation completed
if [ ! -e "${websitesContentFolder}/data/routing/${newSecondaryEdition}/installationCompleted.txt" ]; then
	echo "#	Switching cannot continue because the routing installation did not appear to complete."
	exit 1
fi

### Do switch-over

# Clear this cache - (whose rows relate to a specific routing edition)
${superMysql} cyclestreets -e "truncate map_nearestPointCache;";

# Turn off multiple editions for the duration, and deactivate the current edition
${superMysql} cyclestreets -e "update map_config set multipleEditions = 'no' where id = 1;";
${superMysql} cyclestreets -e "update map_edition set active = 'no' where name = '${currentSecondaryEdition}';";
echo "#	Multiple editions are deactivated for the duration of the switch over."

# Configure the routing engine to use the new edition
routingEngine2ConfigFile=${websitesContentFolder}/routingengine/.config2.sh
echo -e "#!/bin/bash\nBASEDIR=${websitesContentFolder}/data/routing/${newSecondaryEdition}" > $routingEngine2ConfigFile

# Ensure it is executable
chmod a+x $routingEngine2ConfigFile

# Copy the json routing config, if it exists
jsonRoutingConfig=${websitesContentFolder}/data/routing/${newSecondaryEdition}/.config.json
if [ -r "${jsonRoutingConfig}" ]; then
    cp ${jsonRoutingConfig} ${websitesContentFolder}/routingengine/.config2.json
fi


# Remove routing data caches
rm -f ${websitesContentFolder}/data/tempgenerated/*.ridingSurfaceCache.php
rm -f ${websitesContentFolder}/data/tempgenerated/*.routingFactorCache.php

# Restart the routing service
sudo ${routingService2Restart}

# Check the local routing service is currently serving (if it is not it will generate an error forcing this script to stop)
localRouting2Status=$(cat ${statusLog2})

echo "#	Initial status: ${localRouting2Status}"

# Wait until it has restarted
# !! This can loop forever - perhaps because in some situations (e.g a small test dataset) the start has been very quick.
while [[ ! "$localRouting2Status" =~ serving ]]; do
    sleep 12
    localRouting2Status=$(cat ${statusLog2})
    echo "#	Status: ${localRouting2Status}"
done

# Get the locally running service
locallyRunningEdition=$(curl -s -X POST -d "${getRoutingEditionXML}" ${localRouting2Url} | xpath -q -e '/methodResponse/params/param/value/string/text()')

# Check the local service is as requested
if [ "${locallyRunningEdition}" != "${newSecondaryEdition}" ]; then
	echo "#	The local secondary server is running: ${locallyRunningEdition} not the requested edition: ${newSecondaryEdition}"
	exit 1
fi

# Switch the website to the local server and ensure the routingDb is also set
${superMysql} cyclestreets -e "update map_edition set ordering = 1, url = '${localRouting2Url}', active = 'yes' where name = '${newSecondaryEdition}';";

# Restore the multiple editions
${superMysql} cyclestreets -e "update map_config set multipleEditions = 'yes' where id = 1;";

# Photos en route index
${superMysql} ${newSecondaryEdition} -e "call indexPhotos(0);";

# Remove the now previous secondary edition
if [ -z "${keepOldOne}" ]; then
    live-deployment/remove-routing-edition.sh ${currentSecondaryEdition}
else
    echo "#	$(date)	Previous secondary edition ${currentSecondaryEdition} is retained."
fi

### Finishing

# Report
echo "#	$(date)	Completed switch to $newSecondaryEdition"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
