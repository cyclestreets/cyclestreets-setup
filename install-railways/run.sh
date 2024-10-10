#!/bin/bash
# Script to install Railway Stations to CycleStreets external db.
usage()
{
    cat << EOF
    
SYNOPSIS
	$0 -h

OPTIONS
	-h Show this message

DESCRIPTION
	Downloads and installs or updates the table of GB railway stations from the Office of the Rail Regulator.
	Table: csExternal.map_poi_railwaystations

EOF
}

# http://wiki.bash-hackers.org/howto/getopts_tutorial
# An opening colon in the option-string switches to silent error reporting mode.
# Colons after letters indicate that those options take an argument e.g. m takes an email address.
while getopts "h" option ; do
    case ${option} in
        h) usage; exit ;;
	# Missing expected argument
	:)
	    echo "Option -$OPTARG requires an argument." >&2
	    exit 1
	    ;;
	\?) echo "Invalid option: -$OPTARG" >&2 ; exit ;;
    esac
done

# After getopts is done, shift all processed options away with
shift $((OPTIND-1))

# Ensure this script is not run as root
if [ "$(id -u)" == "0" ]; then
    echo "#	This script must not be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e


### DEFAULTS ###

# External database (leave empty if not wanted)
externalDb=csExternal


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
    echo "#	The config file, ${configFile}, does not exist or is not executable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. ${configFile}

# Main body
# Announce starting
echo "#	CycleStreets Railway installation $(date)"
rm /tmp/stations.tsv

# Download
#wget -O /tmp/stations.ods https://dataportal.orr.gov.uk/media/ootlf0cn/table-6329-station-attributes-for-all-mainline-stations.ods

# Convert from ods format using ssconvert which needs installing via:
# sudo apt install gnumeric
# Data is in a specific sheet
ssconvert -S -O 'sheet=6329_station_attributes' --export-type=Gnumeric_stf:stf_csv /tmp/stations.ods /tmp/stations.tsv

# The sheet is suffixed .0, rename
mv /tmp/stations.tsv.0 /tmp/stations.tsv

# Cut the first few lines using sed in-place:
# There are three commentary lines and the column title lines include linebreaks.
sed -i 1,6d /tmp/stations.tsv

head -n1 /tmp/stations.tsv

# Check the head line contains the first station name
firstStation="Abbey Wood"
headline=$(head -n1 /tmp/stations.tsv)
if [[ ! "${headline}" =~ "${firstStation}" ]];then
	echo "#	Extracting data: ${firstStation} is not the first station in the table."
	exit 1
fi

# !! Unfinished

# End of file
