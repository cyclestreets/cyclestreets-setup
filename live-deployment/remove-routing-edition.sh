#!/bin/bash
# Script to remove all the data associated with a CycleStreets routing edition
#
# Run as the cyclestreets user (a check is peformed after the config file is loaded).

# Controls echoed output default to on
verbose=1

# http://ubuntuforums.org/showthread.php?t=1783298
usage()
{
    cat << EOF
SYNOPSIS
	$0 -h -q routingEdition

OPTIONS
	-h Show this message
	-q Suppress narrative messages, error messages are still produced

DESCRIPTION
	routingEdition
		Names a routing database of the form routingYYMMDD, eg. routing151205
		Alternatively the words newest or oldest can be used.
EOF
}


quietmode()
{
    # Turn off verbose messages by setting this variable to the empty string
    verbose=
}


# http://wiki.bash-hackers.org/howto/getopts_tutorial
# See install-routing-data for best example of using this
while getopts ":hq" option ; do
    case ${option} in
        h) usage; exit ;;
        q) quietmode ;;
	\?) echo "Invalid option: -$OPTARG" >&2 ; exit ;;
    esac
done

# After getopts is done, shift all processed options away with
shift $((OPTIND-1))

# Echo output only if the verbose option has been set
vecho()
{
	if [ "${verbose}" ]; then
		echo $1
	fi
}



### Stage 1 - general setup

# Announce start
vecho "#	$(date)	CycleStreets routing edition removal"

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
	flock -n 9 || { echo '#	A routing edition removal is already running' ; exit 1; }

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

# Check the required argument
if [ $# -lt 1 ]
then
    echo "#	Missing required argument: the routing edition to remove."
    exit 1
fi
    
# Check there no additional arguments
if [ $# -gt 1 ]
then
    echo "#	The only permitted argument is the edition to remove."
    exit 1
fi
    
# Check the supplied argument
if [ "$1" = 'oldest' -o "$1" = 'newest' ]
then
    # Find the oldest edition
    # Count the number of routing editions not including the null edition
    numEditions=$(${superMysql} -s cyclestreets<<<"SELECT count(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME != 'routing000000' and SCHEMA_NAME LIKE 'routing%';")

    # Check that there are at least three routing editions - to avoid removing the most recent ones
    if [ -z "${numEditions}" -o "${numEditions}" -lt 3 ]
    then
	vecho "# There are ${numEditions} editions which is too few to use the oldest/newest argument."
	exit 1
    fi

    # Select sort order
    [[ "$1" = 'oldest' ]] && sort='asc' || sort='desc'

    # Determine oldest edition not including the null edition (the -s suppresses the tabular output)
    removeEdition=$(${superMysql} -s cyclestreets<<<"SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME != 'routing000000' and SCHEMA_NAME LIKE 'routing%' order by SCHEMA_NAME ${sort} limit 1;")

else

    # Use the provided edition
    removeEdition=$1
fi

# Check the format is routingYYMMDD
if [[ ! "$removeEdition" =~ routing([0-9]{6}) ]]; then
  echo "#	The supplied argument must specify a routing edition of the form routingYYMMDD, but this was received: ${removeEdition}."
  exit 1
fi

# Extract the date part of the routing database
editionDate=${BASH_REMATCH[1]}

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

# XML for the calls to get the routing edition
xmlrpccall="<?xml version=\"1.0\" encoding=\"utf-8\"?><methodCall><methodName>get_routing_edition</methodName></methodCall>"

# Check the local routing service to make sure that it won't be deleted - but it is not a requirement that it is currently serving routes.
# The status check produces an error if it is not running, so briefly turn off abandon-on-error to catch and report the problem.
set +e

# Note: use /etc/init.d path to the demon, rather than service which is not available to non-root users on debian
localRoutingStatus=$(${routingDaemonLocation} status)
if [ $? -ne 0 ]
then
  vecho "#	Note: there is no current routing service. Routing edition ${removeEdition} removal will proceed."
else

    # Check not already serving this edition

    # POST the request to the server
    currentRoutingEdition=$(curl -s -X POST -d "${xmlrpccall}" ${localRoutingUrl} | xpath -q -e '/methodResponse/params/param/value/string/text()')

    if [ -z "${currentRoutingEdition}" ]; then
	vecho "#	The current edition at ${localRoutingUrl} could not be determined."
	exit 1
    fi

    # Check the fallback routing edition is the same as the proposed edition
    if [ "${removeEdition}" == "${currentRoutingEdition}" ]; then
	vecho "#	The proposed edition to remove: ${removeEdition} is currently being served from ${localRoutingUrl}"
	vecho "#	Stop it using: sudo /bin/systemctl stop cycleroutingd"
	exit 1
    fi
fi

# Restore abandon-on-error
set -e

# Drop the routing and planet databases
${superMysql} cyclestreets -e "drop database if exists ${removeEdition};";
${superMysql} cyclestreets -e "drop database if exists planetExtractOSM${editionDate};";

# Remove the routing folder without generating any prompts or warnings
if [ -n "${websitesContentFolder}" -a -d ${websitesContentFolder}/data/routing/ ]; then
    rm -rf ${websitesContentFolder}/data/routing/${removeEdition}
fi

# Remove from the import output (may only be a symlink from there)
if [ -n "${importContentFolder}" -a -d ${importContentFolder}/output/ ]; then
    rm -rf ${importContentFolder}/output/${removeEdition}
fi

# Report
vecho "#	$(date)	Removed: ${removeEdition}"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
