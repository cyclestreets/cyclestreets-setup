#!/bin/bash
# Script to produce a sample routing database dump for use in a repository
#
# See the README.md file which explains how to use this with the csSampleDb.sh script.

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

# The current database name will be the sample database
sampleRoutingDb=$(${superMysql} -s cyclestreets<<<"select routingDb from map_config limit 1")
echo "# Creating sample routing database for data built with the db named: ${sampleRoutingDb}"


#	Load the zapper
${superMysql} ${sampleRoutingDb} < ${websitesContentFolder}/documentation/schema/cleanSampleRouting.sql

#	Run the zapper - which eliminates unnecessary data, leaving only essential data required to provide routing
#	(This smashes the routing db so consider making a copy first.)
${superMysql} ${sampleRoutingDb} -e "call cleanSampleRouting(\"${sampleRoutingDb}\");"

#	Write
mysqldump --defaults-extra-file=${mySuperCredFile} --hex-blob -hlocalhost --routines --no-create-db --hex-blob ${sampleRoutingDb} | gzip > ${websitesContentFolder}/documentation/schema/sampleRouting.sql.gz

# Archive the data
sampleRoutingData=sampleRoutingData.tar.gz
# Remove the compressed versions of the database and tsv files
rm -f ${websitesContentFolder}/data/routing/${sampleRoutingDb}/dump.sql.gz
rm -f ${websitesContentFolder}/data/routing/${sampleRoutingDb}/tsv.tar.gz
tar czf ${websitesContentFolder}/documentation/schema/${sampleRoutingData} -C ${websitesContentFolder}/data/routing ${sampleRoutingDb}

#	Advise
echo "#	Actions required next:"
echo "# See the README.md file which explains how to use this with the csSampleDb.sh script."
echo "#	Commit the replacement files, sampleRouting.sql.gz and ${sampleRoutingData} (in /documentation/schema/) to the repo."

# Confirm end of script
echo "#	Script completed $(date)"

# Return true to indicate success
:

# End of file
