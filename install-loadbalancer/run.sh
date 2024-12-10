#!/bin/bash
# Installs the load balancer

### Stage 1 - general setup

echo "#	CycleStreets: install load balancer"

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

# Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 9 || { echo '#	An installation is already running' ; exit 1; }


### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
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

# Announce starting
echo "# Load balancer installation $(date)"


## Main body

# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Update sources and packages
apt-get -y update
apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y autoremove

# Apache
apt-get -y install apache2

# PHP
apt-get install -y php

# Munin Node, which should be installed after all other software; see: https://www.digitalocean.com/community/tutorials/how-to-install-the-munin-monitoring-tool-on-ubuntu-14-04
apt-get install -y munin-node
apt-get install -y munin-plugins-extra
apt-get install -y libwww-perl
if [ ! -e /etc/munin/plugins/journeylinger ]; then
	apt-get install -y python3
	ln -s /opt/cyclestreets-setup/live-deployment/cs-munin-journeylinger.sh /etc/munin/plugins/journeylinger
	mkdir -p /websites/www/logs/
	ln -s /var/log/apache2/access.log /websites/www/logs/localhost-access.log
	chmod o+rx /var/log/apache2/
fi
# See: http://munin-monitoring.org/wiki/munin-node-configure
munin-node-configure --suggest --shell | sh
/etc/init.d/munin-node restart
echo "Munin plugins enabled as follows:"
set +e
munin-node-configure --suggest
set -e

# Copy load balancer server config
cp -pr $SCRIPTDIRECTORY/cyclestreets-redirection-load-balancer.conf /etc/apache2/conf-enabled/cyclestreets-redirection-load-balancer.conf
a2enmod rewrite
service apache2 restart


# Report completion
echo "#	Installing load balancer completed"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
