#!/bin/bash
# Script to create a dump of the csExternal database
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

# Use this to remove the ../
ScriptHome=$(readlink -f "${DIR}/..")

# Name of the credentials file
configFile=${ScriptHome}/.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x ${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. ${configFile}

# Report
echo "#	CycleStreets creating a dump of the external schema only (no data)"

# Main Body

# Create the schema file
# Uses some options and a trick with sed to make the schema file avoid overwriting any existing data.
mysqldump --defaults-extra-file=${mySuperCredFile} -hlocalhost csExternal --databases --no-data --skip-add-drop-table | sed 's/CREATE TABLE/CREATE TABLE IF NOT EXISTS/g' > ${websitesContentFolder}/documentation/schema/csExternal.sql

# Create the version with data
if [ ! -z "${csExternalDataFile}" ]; then

    # Report
    echo "#	CycleStreets creating a full external database dump"

    # Dump
    mysqldump --defaults-extra-file=${mySuperCredFile} -hlocalhost -uroot -p${mysqlRootPassword} csExternal | gzip > ${websitesBackupsFolder}/${csExternalDataFile}

    # Advise
    echo "#	Advise: on the backup machine run this to copy the dump:"
    echo "#	scp www.cyclestreets.net:${websitesBackupsFolder}/${csExternalDataFile} ${websitesBackupsFolder}"
    echo "#	Create a new csExternal database (or drop all the tables from any existing one) and use this to restore:"
    echo "#	gunzip < ${websitesBackupsFolder}/${csExternalDataFile} | mysql csExternal -uroot -pROOT PASSWORD HERE"

fi

# Confirm end of script
echo "#	Script completed $(date)"

# Return true to indicate success
:

# End of file
