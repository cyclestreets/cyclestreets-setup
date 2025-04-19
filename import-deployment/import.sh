#!/bin/bash
# Script to do a new CycleStreets import run
# Run as the cyclestreets user (a check is peformed after the config file is loaded).

usage()
{
    cat << EOF

SYNOPSIS
	$0 import.sh -h -f config

OPTIONS
	-f Force overwite existing edition
	-h Show this message

ARGUMENTS
	config
		Configuration file

DESCRIPTION
	Script for building new routing edition - but see also newbuild.sh which is a wrapper for this script.
	Optional force argument is used to overwrite existing routing edition - which is convenient during development testing.

EOF
}

# Setting to force overwrite of current data
force=0

# http://wiki.bash-hackers.org/howto/getopts_tutorial
# An opening colon in the option-string switches to silent error reporting mode.
# Colons after letters indicate that those options take an argument e.g. m takes an email address.
while getopts "hf" option ; do
    case ${option} in
        h) usage; exit ;;
	f)
	    # Set the notification email address
	    force=1
	    ;;
	\?) echo "Invalid option: -$OPTARG" >&2 ; exit ;;
    esac
done

# After getopts is done, shift all processed options away with
shift $((OPTIND-1))

# Start an import run
echo "#	$(date) CycleStreets import"

# Ensure this script is NOT run as root
if [ "$(id -u)" = "0" ]; then
    echo "#	This script must not be be run as root." 1>&2
    exit 1
fi

# Check required argument
if [ -z "$1" ]; then
    echo "#	$0 No config argument" 1>&2
    exit 1
fi
importConfig=$1

# Bomb out if something goes wrong
set -e


### DEFAULTS ###

# Stop the routing service during import unless this setting is empty.
stopRoutingDuringImport=yes


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
    echo "#	The config file, ${configFile}, does not exist or is not executable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. ${configFile}


## Main body of script

# Ensure this script is run as cyclestreets user
if [ ! "$(id -nu)" = "${username}" ]; then
    echo "#	This script must be run as user ${username}, rather than as $(id -nu)." 1>&2
    exit 1
fi

# Check the import folder is defined
if [ -z "${importContentFolder}" ]; then
    echo "#	The import folder is not defined."
    exit 1
fi

# The new routing edition will be written to this location
importMachineEditions=${importContentFolder}/output

#	Report where logging is occurring
echo "#	Progress is logged in ${importContentFolder}/log.txt"


# Guess the likely name of the routing edition, which is usually routingYYMMDD
# !! This is messy and probably unnecesary.
likelyEdition=routing$(date +%y%m%d)

# Check whether the edition already exists either as a directory or symbolic link
if [ -d ${importMachineEditions}/${likelyEdition} -o -L ${importMachineEditions}/${likelyEdition} ]; then
    echo "#	The edition already exists, check this folder: ${importMachineEditions}/${likelyEdition}"

    # An argument can be used to force this to continue
    if [ "$force" != "1" ]; then
	echo "#	Abandoning - use force option to override"
	exit 1
    else
	echo "#	Continuing due to force option"
    fi
fi

# Lock directory
lockdir=/var/lock/cyclestreets
mkdir -p $lockdir

# Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 9 || { echo '#	An import is already running' ; exit 1; }

# Removes coverage files - requires passwordless sudo
sudo ${ScriptHome}/utility/removeCoverageCSV.sh

# Useful binding
# The defaults-extra-file is a positional argument which must come first.
superMysql="mysql --defaults-extra-file=${mySuperCredFile} -hlocalhost"

# Stop the routing service - if required
if [ -n "${stopRoutingDuringImport}" ]; then

    # Stop the routing service (using command that matches pattern setup in passwordless sudo)
    sudo /bin/systemctl stop cyclestreets

    # Close the website
    ${superMysql} cyclestreets -e "update map_config set status = 'maintenance', journeyPlannerStatus = 'closed', notice = 'Building a new routing edition' where id = 1;";
fi

# Move to the right place
cd ${importContentFolder}

# Start the import (sets a file lock called /var/lock/cyclestreets/importInProgress to stop multiple imports running)
routingEdition=`php run.php $importConfig`

# Reopen the website if it was closed earlier
if [ -n "${stopRoutingDuringImport}" ]; then
    ${superMysql} cyclestreets -e "update map_config set status = 'live', journeyPlannerStatus = 'live', notice = '' where id = 1;";
fi

# Report completion and next steps
echo "#	$(date)	CycleStreets import has created a new edition: ${routingEdition}"
echo "#	To prepare this data for serving locally, remotely or both:"
echo "#	Routing builds:"
echo "#	Locally  run: ${ScriptHome}/live-deployment/installLocalLatestEdition.sh"
echo "#	Remotely run: ${username}@other:${ScriptHome}\$ live-deployment/install-routing-data.sh"
echo "#	POIs builds:"
echo "#	Locally  run: ${ScriptHome}/live-deployment/install-pois-data.sh localhost"
echo "#	Remotely run: ${username}@other:${ScriptHome}\$ live-deployment/install-pois-data.sh"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
