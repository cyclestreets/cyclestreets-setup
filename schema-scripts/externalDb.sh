#!/bin/bash
# Script to manage CycleStreets schema
#
# Tested on 13.04 View Ubuntu version using: lsb_release -a

echo "#	CycleStreets schema script $(date)"

# Ensure this script is not run as root
if [ "$(id -u)" == "0" ]; then
    echo "#	This script must not be run as root." 1>&2
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

# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Report
echo "#	CycleStreets schema script starting"

# Main Body

# Create the schema file
# Uses some options and a trick with sed to make the schema file avoid overwriting any existing data.
mysqldump -hlocalhost -uroot -p${mysqlRootPassword} csExternal --databases --no-data --skip-add-drop-table | sed 's/CREATE TABLE/CREATE TABLE IF NOT EXISTS/g' > ${websitesContentFolder}/documentation/schema/csExternal.sql

# Create the version with data
if [ ! -z "${csExternalDataFile}" ]; then

    # Report
    echo "#	CycleStreets schema script starting"

    # Dump
    mysqldump -hlocalhost -uroot -p${mysqlRootPassword} csExternal | gzip > ${websitesBackupsFolder}/${csExternalDataFile}

    # Advise
    echo "#	Advise: on the backup machine copy this dump:"
    echo "#	scp www.cyclestreets.net:${websitesBackupsFolder}/${csExternalDataFile} ${websitesBackupsFolder}"
fi

# Confirm end of script
echo "#	Script completed $(date)"

# Return true to indicate success
:

# End of file
