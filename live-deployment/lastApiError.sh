#!/bin/bash
# Script to return last line of api error log
usage()
{
	cat << EOF
SYNOPSIS
	$0 -h -s

OPTIONS
	-h Show this message
	-s If set reads from log defined by the secure, i.e. SSL virtual host.

DESCRIPTION
	Returns last line of the apache error log for virtual host cyclestreets API.

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
#echo "tail -n1 ${websitesLogsFolder}/${mainName}${secureLog}-error.log"

# Finish
tail -n1 ${websitesLogsFolder}/${mainName}${secureLog}-error.log

# End of file
