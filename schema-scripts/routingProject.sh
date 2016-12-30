#!/bin/bash
# Script to produce a sample routing database dump for an academic project

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
echo "#	CycleStreets schema script starting"

# Main Body

# The current database name will be the sample database
sampleRoutingDb=$(${superMysql} -s cyclestreets<<<"select routingDb from map_config limit 1")
# Use the date part of that (from character 7) as the basis for getting the planet db.
samplePlanetDb=planetExtractOSM${sampleRoutingDb:7}
echo "# Using routing data from the db named: ${sampleRoutingDb} and planet ${samplePlanetDb}"

#	Write
#	Routing db
mysqldump --defaults-extra-file=${mySuperCredFile} --hex-blob -hlocalhost ${sampleRoutingDb} map_way map_routingFactor map_wayName map_osmBicycleRoute map_way_tags | gzip > ${websitesContentFolder}/${sampleRoutingDb}Project.sql.gz
#	Planet Extract db
mysqldump --defaults-extra-file=${mySuperCredFile} --hex-blob -hlocalhost ${samplePlanetDb} osm_wayTag | gzip > ${websitesContentFolder}/${samplePlanetDb}Project.sql.gz

#	Advise
echo "#	Actions required next:"
echo "#	End user will need to create a database and load the data into it using:"
echo "mysql -e \"create database ${sampleRoutingDb} default character set utf8 default collate utf8_unicode_ci;\""
echo "gunzip < ${sampleRoutingDb}Project.sql.gz | mysql ${sampleRoutingDb}"
echo "mysql -e \"create database ${samplePlanetDb} default character set utf8 default collate utf8_unicode_ci;\""
echo "gunzip < ${samplePlanetDb}Project.sql.gz | mysql ${samplePlanetDb}"

# Confirm end of script
echo "#	Script completed $(date)"

# Return true to indicate success
:

# End of file
