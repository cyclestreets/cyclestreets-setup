#!/bin/bash
# Installs the Photon geocoder

### Stage 1 - general setup

echo "#	CycleStreets: install Photon geocoder"

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#     This script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

# Lock directory
lockdir=/var/lock/cyclestreets
mkdir -p $lockdir

# Set a lock file; see: https://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 9 || { echo '#	An installation is already running' ; exit 1; }


### CREDENTIALS ###

# Get the script directory see: https://stackoverflow.com/a/246128/180733
# The multi-line method of geting the script directory is needed to enable the script to be called from elsewhere.
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
    echo "#	The config file, ${configFile}, does not exist or is not executable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. $SCRIPTDIRECTORY/${configFile}

# Update sources and packages
apt-get -y update
apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y autoremove

# Photon requires Java
apt-get -y install default-jre


# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Announce starting
echo "# Photon geocoder installation $(date)"


## Main body

# https://github.com/komoot/photon
# https://github.com/komoot/leaflet.photon
# https://photon.komoot.io/


# Set up installation directory
mkdir -p /opt/photon/
chown $username /opt/photon/
cd /opt/photon/

# Get the latest distribution
VERSION='0.3.5'
if [ ! -f "/opt/photon/photon-${VERSION}.jar" ]; then
	$asCs wget "https://github.com/komoot/photon/releases/download/${VERSION}/photon-${VERSION}.jar"
fi

# Get the latest data
apt-get -y install pbzip2
if [ ! -d /opt/photon/photon_data ]; then
	echo "Downloading compiled data file (at November 2021 this is 76GB and unpacks to 146GB)"
	$asCS wget https://download1.graphhopper.com/public/photon-db-latest.tar.bz2
	$asCS pbzip2 -d photon-db-latest.tar.bz2
	$asCS tar vxf photon-db-latest.tar
fi

# Install init.d service; this essentially runs `java -jar photon-${VERSION}.jar`
if [ ! -L /etc/init.d/photon ]; then
	cp -p "${SCRIPTDIRECTORY}/photon.init.d" /opt/photon/
	sed -i "s/version=DOWNLOADED_VERSION_HERE/version=\"${VERSION}\"/" /opt/photon/photon.init.d
	ln -s /opt/photon/photon.init.d /etc/init.d/photon
	chmod +x /opt/photon/photon.init.d
fi

# Start service at startup
sudo update-rc.d photon defaults

# Start the service
service photon start
echo "Photon started using: service photon start"


# Report completion
echo "#	Installing Photon geocoder completed"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
