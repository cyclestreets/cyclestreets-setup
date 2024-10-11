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

# Useful bindings
# The defaults-extra-file is a positional argument which must come first.
superMysql="mysql --defaults-extra-file=${mySuperCredFile} -hlocalhost"
superMysqlImport="mysqlimport --defaults-extra-file=${mySuperCredFile} -hlocalhost"
externalDb=csExternal
tmpDir=/tmp

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

# Clear out any left over previous installation
rm -f ${tmpDir}/stations.*

# Download
wget -O ${tmpDir}/stations.ods https://dataportal.orr.gov.uk/media/ootlf0cn/table-6329-station-attributes-for-all-mainline-stations.ods

# Convert from ods format using ssconvert which needs installing via:
# sudo apt install gnumeric
# Data is in a specific sheet, format output as tab separated, but requires using .txt extension
ssconvert -S -O 'sheet=6329_station_attributes separator="	" format=raw quote=""' ${tmpDir}/stations.ods ${tmpDir}/stations.txt

# No longer needed
rm -f ${tmpDir}/stations.ods

# The sheet is suffixed .0, rename
mv ${tmpDir}/stations.txt.0 ${tmpDir}/stations.tsv

# Cut the first few lines using sed in-place:
# There are three commentary lines and the column title lines include linebreaks.
sed -i 1,6d ${tmpDir}/stations.tsv

# First line
# head -n1 ${tmpDir}/stations.tsv

# Check the head line contains the first station name
firstStation="Abbey Wood"
headline=$(head -n1 ${tmpDir}/stations.tsv)
if [[ ! "${headline}" =~ "${firstStation}" ]];then
	echo "#	Extracting data: ${firstStation} is not the first station in the table."
	exit 1
fi

# Load table definition
$superMysql ${externalDb} < ${DIR}/railway_station.sql

# Load the data
$superMysqlImport ${externalDb} ${tmpDir}/stations.tsv

# No longer needed
rm -f ${tmpDir}/stations.tsv

# Load helper
$superMysql ${externalDb} < ${websitesContentFolder}/documentation/schema/convertOSGB36.sql

# Optimize
$superMysql ${externalDb} < ${DIR}/optimize_station.sql

# Comment
$superMysql ${externalDb} -e "alter table map_poi_railwaystations comment 'Railway stations updated from ORR $(date)';"

# Done
echo "#	Railway stations table updated successfully."

# Indicate success
:

# End of file
