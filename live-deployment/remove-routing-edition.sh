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
	$0 -h -q [routingEdition]

OPTIONS
	-h Show this message
	-q Suppress helpful messages, error messages are still produced

DESCRIPTION
	routingEdition
		Names a routing database of the form routingYYMMDD, eg. routing151205
		Defaults to the oldest version avaialble.
EOF
}


quietmode()
{
    # Turn off verbose messages by setting this variable to the empty string
    verbose=
}


# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hq" option ; do
    case ${option} in
        h) usage; exit ;;
        q) quietmode ;;
	\?) echo "Invalid option: -$OPTARG" >&2 ; exit ;;
    esac
done


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

# Check the supplied argument - if exactly one use it, else default to latest routing db
if [ $# -eq 1 ]
then

    # Allocate that argument
    oldEdition=$1
else

    # Count the number of routing editions not including the null edition
    numEditions=$(${superMysql} -s cyclestreets<<<"SELECT count(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME != 'routing000000' and SCHEMA_NAME LIKE 'routing%';")

    # Check that there are at least three routing editions - to avoid removing the latest ones.
    if [ -z "${numEditions}" -o "${numEditions}" -lt 3 ]
    then
	vecho "# There are ${numEditions} editions which is too few to use the oldest as a default value."
	exit 1
    fi

    # Determine oldest edition not including the null edition (the -s suppresses the tabular output)
    oldEdition=$(${superMysql} -s cyclestreets<<<"SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME != 'routing000000' and SCHEMA_NAME LIKE 'routing%' order by SCHEMA_NAME asc limit 1;")
fi

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
if [ -z "${localRoutingServer}" ]; then
	echo "#	The local routing service is not specified."
	exit 1
fi

# XML for the calls to get the routing edition
xmlrpccall="<?xml version=\"1.0\" encoding=\"utf-8\"?><methodCall><methodName>get_routing_edition</methodName></methodCall>"

# Check the local routing service to make sure that it won't be deletes - but it is not a requirement that it is currently serving routes.
# The status check produces an error if it is not running, so briefly turn off abandon-on-error to catch and report the problem.
set +e

# Note: use /etc/init.d path to the demon, rather than service which is not available to non-root users on debian
localRoutingStatus=$(${routingDaemonLocation} status)
if [ $? -ne 0 ]
then
  vecho "#	Note: there is no current routing service. Routing edition ${oldEdition} removal will proceed."
else

    # Check not already serving this edition

    # POST the request to the server
    currentRoutingEdition=$(curl -s -X POST -d "${xmlrpccall}" ${localRoutingServer} | xpath -q -e '/methodResponse/params/param/value/string/text()')

    if [ -z "${currentRoutingEdition}" ]; then
	vecho "#	The current edition at ${localRoutingServer} could not be determined."
	exit 1
    fi

    # Check the fallback routing edition is the same as the proposed edition
    if [ "${oldEdition}" == "${currentRoutingEdition}" ]; then
	vecho "#	The proposed edition to remove: ${oldEdition} is currently being served from ${localRoutingServer}"
	vecho "#	Stop it using: sudo service cycleroutingd stop"
	exit 1
    fi
fi

# Restore abandon-on-error
set -e

# Check the format is routingYYMMDD
if [[ ! "$oldEdition" =~ routing([0-9]{6}) ]]; then
  echo "#	The supplied argument must specify a routing edition of the form routingYYMMDD, but this was received: ${oldEdition}."
  exit 1
fi

# Extract the date part of the routing database
importDate=${BASH_REMATCH[1]}

# Drop the routing and planet databases
${superMysql} cyclestreets -e "drop database if exists ${oldEdition};";
${superMysql} cyclestreets -e "drop database if exists planetExtractOSM${importDate};";

# Remove the routing folder without generating any prompts or warnings
rm -rf ${websitesContentFolder}/data/routing/${oldEdition}

# Report
vecho "#	$(date)	Removed: $oldEdition"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
