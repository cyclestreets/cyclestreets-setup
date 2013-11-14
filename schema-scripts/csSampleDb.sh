#!/bin/bash
# Script to produce a sample cyclestreets database dump for use in a repository
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
credentials="-hlocalhost -uroot -p${mysqlRootPassword}"
sampleDb=csSample
csBackup=/websites/www/backups/www_cyclestreets.sql.gz

# Check a backup of the cyclestreets database is available
if [ ! -r ${csBackup} ]; then

    echo "#	First obtain an up to date copy of the cyclestreets database, usually from the daily backup:"
    echo "#	scp www.cyclestreets.net:${csBackup} ${csBackup}"
    exit
fi

#	Create the new database
mysql ${credentials} -e "drop database if exists ${sampleDb};"
mysql ${credentials} -e "create database ${sampleDb} default character set utf8 default collate utf8_unicode_ci;"

#	Load a copy of the cyclestreets database into the new db
gunzip < ${csBackup} | mysql ${credentials} ${sampleDb}

#	Load the zapper - procedures which clean the database
mysql ${credentials} ${sampleDb} < ${websitesContentFolder}/documentation/schema/prepareSampleCycleStreetsDB.sql

#	Run the zapper - which eliminates all user generated and sensitive data, leaving only essential data required to run the system
mysql ${credentials} ${sampleDb} -e "call prepareSampleCycleStreetsDB();"

#	Write (requires a subsequent commit to become part of the repo)
mysqldump ${sampleDb} ${credentials} --routines --no-create-db > ${websitesContentFolder}/documentation/schema/cyclestreets.sql

#	Advise
echo "#	Actions required next:"
echo "#	Commit the updated schema to the repository."

# Confirm end of script
echo "#	Script completed $(date)"

# Return true to indicate success
:

# End of file
