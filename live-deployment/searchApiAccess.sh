#!/bin/bash
# Script to search backwards through api access log for unique_id, with timeout.
usage()
{
	cat << EOF
SYNOPSIS
	$0 -h -s unique_id

OPTIONS
	-h Show this message
	-s If set searchs log defined by the secure, i.e. SSL virtual host.

DESCRIPTION
	Searches backwards through access log defined by the Apache cyclestreets API virtual host.
    The search looks for unique_id, with timeout of one second.
	The unique_id is an option used by Apache to mark requests in an access log with a unique reference.

EOF
}

# String insert that identifies the secure log variant, if needed
secureLog=

# http://wiki.bash-hackers.org/howto/getopts_tutorial
# See install-routing-data for best example of using this
while getopts "hs" option ; do
	case ${option} in
		h) usage; exit ;;
		s)
		# Set read from secure log
		secureLog=_ssl
		;;
	\?) echo "Invalid option: -$OPTARG" >&2 ; exit ;;
	esac
done

# After getopts is done, shift all processed options away with
shift $((OPTIND-1))

### Stage 1 - general setup

# Ensure this script is NOT run as root
if [ "$(id -u)" = "0" ]; then
	echo "#	This script must NOT be run as root." 1>&2
	exit 1
fi

# Check required argument
if [ $# -ne 1 ]; then
	# Report and abandon
	echo -e "#\t	There must be exactly one argument." 1>&2
	exit 1
fi

# Bind first argument
uniqueId=$1

### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The multi-line method of geting the script directory is needed because this script is likely symlinked from cron
SOURCE="${BASH_SOURCE[0]}"
DIR="$( dirname "$SOURCE" )"
while [ -h "$SOURCE" ]
do
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
  DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPTDIRECTORY=$DIR

# Define the location of the credentials file relative to script directory
configFile=../.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x $SCRIPTDIRECTORY/${configFile} ]; then
	echo "# The config file, ${configFile}, does not exist or is not executable - copy your own based on the ${configFile}.template file." 1>&2
	exit 1
fi

# Load the credentials
. $SCRIPTDIRECTORY/${configFile}

# Main part of the name used to specify the log file
mainName=${apiHostname}
# Fix up special case for main site
if [ "${apiHostname}" = "api.cyclestreets.net" ]; then
	mainName=api
fi

# Debug
#echo "(timeout 1 tac ${websitesLogsFolder}/${mainName}${secureLog}-access.log || : ) | grep -F -m1 ${uniqueId}"

# Search
# Limit search time to one second, while searching backwards through the access log, return the first match with the unique id
(timeout 1 tac ${websitesLogsFolder}/${mainName}${secureLog}-access.log || : ) | grep -F -m1 ${uniqueId}

# End of file
