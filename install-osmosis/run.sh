#!/bin/bash

# Installs Osmosis
# Script to install CycleStreets on Ubuntu
# https://github.com/cyclestreets/cyclestreets/wiki/Osmosis-planet-extractor
#
# Tested on 13.04 View Ubuntu version using: lsb_release -a
# This script is idempotent - it can be safely re-run without destroying existing data

echo "#	CycleStreets / Osmosis installation $(date)"

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

mkdir -p /usr/local/osmosis

# wget the latest to here
if [ ! -e /usr/local/osmosis/osmosis-latest.tgz ]; then
    wget -O /usr/local/osmosis/osmosis-latest.tgz http://dev.openstreetmap.org/~bretth/osmosis-build/osmosis-latest.tgz
fi

# Create a folder for the new version
mkdir -p /usr/local/osmosis/osmosis-0.43.1

# Unpack into it
tar xzf /usr/local/osmosis/osmosis-latest.tgz -C /usr/local/osmosis/osmosis-0.43.1

# Remove the download archive
# rm -f /usr/local/osmosis/osmosis-latest.tgz

# Repoint current to the new install
rm -f /usr/local/osmosis/current

# Whatever the version number is here - replace the 0.43.1
ln -s /usr/local/osmosis/osmosis-0.43.1 /usr/local/osmosis/current

# This last bit only needs to be done first time round, not for upgrades. It keeps the binary pointing to the current osmosis.
if [ ! -L /usr/local/bin/osmosis ]; then
    ln -s /usr/local/osmosis/current/bin/osmosis /usr/local/bin/osmosis
fi

echo "#	Completed installation of osmosis"

# end of file
