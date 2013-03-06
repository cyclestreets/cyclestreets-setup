#!/bin/bash
# Script to install CycleStreets Postcodes on Ubuntu
# Tested on 12.10 (View Ubuntu version using 'lsb_release -a')
# This script is idempotent - it can be safely re-run without destroying existing data

echo "#	CycleStreets Postcode installation $(date)"

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#	This script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The second single line solution from that page is probably good enough as it is unlikely that this script itself will be symlinked.
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPTDIRECTORY=$DIR

# Name of the credentials file
configFile=../.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x ./${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. ./${configFile}

# Logging
# Use an absolute path for the log file to be tolerant of the changing working directory in this script
setupLogFile=$SCRIPTDIRECTORY/log.txt
touch ${setupLogFile}
echo "#	CycleStreets postcode installation in progress, follow log file with: tail -f ${setupLogFile}"
echo "#	CycleStreets postcode installation $(date)" >> ${setupLogFile}

# ONS folder
onsFolder=${websitesContentFolder}/import/ONSdata

# Switch to ONS data folder
cd ${onsFolder}

# Check the data has been downloaded
if [ ! -r ONSdata.csv ]; then

# Provide dowload instructions
    echo "#
#	STOPPING: Required data files are not present.
#
#	Download the csv version of ONSPD data from:
#	http://www.ons.gov.uk/ons/guide-method/geography/products/postcode-directories/-nspp-/index.html
#
#	Extract the .csv from the Data folder within the archive to ${onsFolder}/ONSdata.csv
#	cd ${onsFolder}
#	This is an alternative source of data:
#	wget http://parlvid.mysociety.org:81/os/ONSPD_FEB_2011_UK_O.zip
#	unzip ONSPD_FEB_2011_UK_O.zip
#	rm ONSPD_FEB_2011_UK_O.zip
#	mv ONSPD_FEB_2011_UK_O.csv ONSdata.csv";

 # Terminate the script
 exit 1;
fi

# WIP


# Confirm end of script
echo -e "#	All now installed $(date)"

# Return true to indicate success
:

# End of file
