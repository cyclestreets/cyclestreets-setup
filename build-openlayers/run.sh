#!/bin/bash
# Builds a configured OpenLayers.js

### Stage 1 - general setup

echo "#	CycleStreets: build a configured OpenLayers.js file"

# Ensure this script is NOT run as root (it should be run as the cyclestreets user, having sudo rights as setup by install-website)
if [ "$(id -u)" = "0" ]; then
    echo "#	This script must NOT be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

# Lock directory
lockdir=/var/lock/cyclestreets
mkdir -p $lockdir

# Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 9 || { echo '#	An installation is already running' ; exit 1; }


### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The multi-line method of geting the script directory is needed because this script is likely symlinked from cron
SOURCE="${BASH_SOURCE[0]}"
DIR="$( dirname "$SOURCE" )"
while [ -h "$SOURCE" ]
do 
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
  DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPTDIRECTORY=$DIR

# Define the location of the credentials file relative to script directory
configFile=../.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x $SCRIPTDIRECTORY/${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. $SCRIPTDIRECTORY/${configFile}


## Main body

# OpenLayers folder
olf=${websitesContentFolder}/openlayers

# Configuration file
OLconfig=${SCRIPTDIRECTORY}/CycleStreets.cfg

# Alternatively, leave blank for a full build
#OLconfig=

# Change to this folder to do the build
cd ${olf}/build

# Use this to generate a configured build
${olf}/build/build.py ${OLconfig}

# Move it to the correct place
mv ${olf}/build/OpenLayers.js ${olf}/

# Report completion
echo "#	Building OpenLayers.js completed"

# Remove the lock file
) 9>$lockdir/build-openlayers

# End of file
