#!/bin/bash
# Script to produce a sample routing database dump for use in a repository

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

#	Load the zapper
mysql ${credentials} ${sampleRoutingDb} < ${websitesContentFolder}/documentation/schema/cleanSampleRouting.sql

#	Run the zapper - which eliminates unnecessary data, leaving only essential data required to provide routing
#	(This smashes the routing db so consider making a copy first.)
mysql ${credentials} ${sampleRoutingDb} -e "call cleanSampleRouting();"

#	Write
mysqldump ${sampleRoutingDb} ${credentials} --routines --no-create-db | gzip > ${websitesContentFolder}/documentation/schema/routingSample.sql.gz

# Archive the data
sampleRoutingData=routingSampleData.tar.gz
tar czf ${websitesContentFolder}/documentation/schema/${sampleRoutingData} -C ${websitesContentFolder}/data/routing ${sampleRoutingDb}

#	Advise
echo "#	Actions required next:"
echo "#	Add the new files, ${sampleRoutingDb}.sql.gz and ${sampleRoutingData} (in /documentation/schema/) to the repo and remove the old one, then commit."
echo "#	Fixup the install-website script from https://github.com/cyclestreets/cyclestreets-setup to refer to the new db."

# Confirm end of script
echo "#	Script completed $(date)"

# Return true to indicate success
:

# End of file
