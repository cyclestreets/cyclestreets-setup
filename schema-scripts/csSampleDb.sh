#!/bin/bash
# Script to produce a sample cyclestreets database dump for use in a repository

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

# Narrative
echo "#	CycleStreets schema script starting $(date)"

# Main Body
sampleDb=csSample
csBackup=${websitesBackupsFolder}/www_cyclestreets.sql.gz

# Check that a backup of the cyclestreets database is available
if [ ! -r ${csBackup} ]; then

    echo "#	First obtain an up to date copy of the cyclestreets database, usually from the daily backup:"
    echo "#	scp www.cyclestreets.net:${csBackup} ${csBackup}"
    exit
fi

#	Create the new database
${superMysql} -e "drop database if exists ${sampleDb};"
${superMysql} -e "create database ${sampleDb} default character set utf8 default collate utf8_unicode_ci;"

#	Load a copy of the cyclestreets database into the new db
gunzip < ${csBackup} | ${superMysql} ${sampleDb}

#	Load the zapper - procedures which clean the database
${superMysql} ${sampleDb} < ${websitesContentFolder}/documentation/schema/prepareSampleCycleStreetsDB.sql

#	Run the zapper - which eliminates all user generated and sensitive data, leaving only essential data required to run the system
${superMysql} ${sampleDb} -e "call prepareSampleCycleStreetsDB();"

#	Write (requires a subsequent commit to become part of the repo)
mysqldump --defaults-extra-file=${mySuperCredFile} ${sampleDb} --routines --no-create-db > ${websitesContentFolder}/documentation/schema/cyclestreetsSample.sql

#	Advise
echo "#	Actions required next:"
echo "#	Commit the updated schema to the repository."
echo "#	Build a routing sample db."

# Confirm end of script
echo "#	Script completed $(date)"

# Return true to indicate success
:

# End of file
