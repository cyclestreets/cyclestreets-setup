#!/bin/bash
# Installs the Photon geocoder
# Takes about 3 hours in total, 90 minute download plus similar to unpack.

# Creates a service:
#
# wget http://localhost:2322/api?q=station+road
#

# Updating
# Apply these steps before re-running the script:
#
# 1. cd /opt/photon
#
# 2. Move or delete the old data folder:
#    mv photon_data photon_data.YYMMDD
#
# 3. Remove the link to the init so a new one will be created:
#    sudo rm /etc/init.d/photon
#
# 4. Set VERSION
#
# 5. Set photonDatabase
#

### Stage 1 - general setup

echo "#	$(date) CycleStreets: install Photon geocoder"

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


# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Announce starting
echo "# $(date) Photon geocoder installation"


## Main body

# https://github.com/komoot/photon
# https://github.com/komoot/leaflet.photon
# https://photon.komoot.io/


# Photon requires Java 21+
# At ubuntu jammy this won't work:
# apt-get -y install default-jre
# ... so use
apt-get -y install openjdk-21-jre

# Set up installation directory
mkdir -p /opt/photon/
chown $username /opt/photon/
cd /opt/photon/

# Get the latest distribution
VERSION='1.3.0'
if [ ! -f "/opt/photon/photon-${VERSION}.jar" ]; then
	$asCs wget "https://github.com/komoot/photon/releases/download/${VERSION}/photon-${VERSION}.jar"
fi

# Get the latest data
photonDatabase=photon-db-planet-1.0-latest
apt-get -y install pbzip2
if [ ! -d /opt/photon/photon_data ]; then
	# Note: twice that amount of space is needed because of the tar extract phase
	echo "# $(date) Downloading compiled data file (at October 2026 this is 94B and unpacks to 390GB"
	$asCS wget https://download1.graphhopper.com/public/${photonDatabase}.tar.bz2.md5
	$asCS wget https://download1.graphhopper.com/public/${photonDatabase}.tar.bz2
	echo "# Check md5"
	$asCS md5sum -c ${photonDatabase}.tar.bz2.md5
	echo "# $(date) Parallel uncompressing database file"
	$asCS pbzip2 -d ${photonDatabase}.tar.bz2
	# Makes a copy as it extracts, so doubling the space requirement
	echo "# $(date) Unpacking photon database"
	$asCS tar vxf ${photonDatabase}.tar
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
systemctl start photon
echo "# $(date) Photon started"


# Report completion
echo "#	$(date) Installing Photon geocoder completed"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
