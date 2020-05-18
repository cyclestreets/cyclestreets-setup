#!/bin/bash
# Installs the tilecache

### Stage 1 - general setup

echo "#	CycleStreets: install tilecache"

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
    echo "#	The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. $SCRIPTDIRECTORY/${configFile}

# Announce starting
echo "# Tilecache installation $(date)"

# Check the options
if [ -z "${tilecacheHostname}" -o -z "${tilecacheContentFolder}" ]; then
    echo "#	The tilecache options are not configured, abandoning installation."
    exit 1
fi


## Main body

# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Apache
apt-get -y install apache2
a2enmod rewrite
a2enmod ssl

# PHP
apt-get -y install php libapache2-mod-php

# ImageMagick needed for upscaling
apt-get -y install imagemagick php-imagick

# Install path to content and go there
mkdir -p "${tilecacheContentFolder}"

# Make the folder group writable
chmod -R g+w "${tilecacheContentFolder}"

# Switch to it
cd "${tilecacheContentFolder}"

# Make sure the webserver user can write to the tilecache, by setting this as the owner
chown -R www-data.${rollout} "${tilecacheContentFolder}"

# Add the user to the rollout group, if not already there
if ! groups ${username} | grep "\b${rollout}\b" > /dev/null 2>&1
then
        usermod -a -G ${rollout} ${username}
fi

# Create/update the tilecache repository, ensuring that the files are owned by the CycleStreets user (but the checkout should use the current user's account - see http://stackoverflow.com/a/4597929/180733 )
if [ ! -d "${tilecacheContentFolder}/.git" ]
then
	${asCS} git clone https://github.com/cyclestreets/tilecache.git "${tilecacheContentFolder}/"
else
	${asCS} git pull
fi

# Make the repository writable to avoid permissions problems when manually editing
chmod -R g+w "${tilecacheContentFolder}"
chgrp -R ${rollout} -R "${tilecacheContentFolder}"

# Create the config file if it doesn't exist, and write in the configuration
if [ ! -f "${tilecacheContentFolder}/.config.php" ]; then
	${asCS} cp -p .config.php.template .config.php
fi

# Create logs folder
mkdir -p "${websitesLogsFolder}"

# Create the VirtualHost config if it doesn't exist, and write in the configuration
vhConf=/etc/apache2/sites-available/tile.conf
if [ ! -f ${vhConf} ]; then
	cp -p .apache-vhost.conf.template ${vhConf}
	sed -i "s|tile.example.com|${tilecacheHostname}|g" ${vhConf}
	sed -i "s|/var/www/tile|${tilecacheContentFolder}|g" ${vhConf}
	sed -i "s|/var/log/apache2|${websitesLogsFolder}|g" ${vhConf}
fi

# Enable the VirtualHost; this is done manually to ensure the ordering is correct
if [ ! -L /etc/apache2/sites-enabled/700-tile.conf ]; then
    ln -s ${vhConf} /etc/apache2/sites-enabled/700-tile.conf
fi

# Create the SSL VirtualHost config if it doesn't exist, and write in the configuration
vhSslConf=/etc/apache2/sites-available/tile_ssl.conf

# Note: tilecacheSSL is boolean and cannot be used in the square brackets
if ${tilecacheSSL} && [ ! -f ${vhSslConf} ]; then
	cp -p .apache-vhost.conf.template ${vhSslConf}
	sed -i "s|tile.example.com|${tilecacheHostname}|g" ${vhSslConf}
	sed -i "s|/var/www/tile|${tilecacheContentFolder}|g" ${vhSslConf}
	sed -i "s|/var/log/apache2/tile-|/var/log/apache2/tile_ssl-|g" ${vhSslConf}
	sed -i "s|/var/log/apache2|${websitesLogsFolder}|g" ${vhSslConf}
	sed -i "s|/etc/ssl/certs|/etc/apache2/sslcerts|g" ${vhSslConf}
	
	#  Special SSL customizations
	sed -i "s|:80|:443|g" ${vhSslConf}
	sed -i "s|#SSL|SSL|g" ${vhSslConf}
	
	# Certbot
	sudo apt-get update
	sudo apt-get -y install software-properties-common
	sudo add-apt-repository -y universe
	sudo add-apt-repository -7 ppa:certbot/certbot
	sudo apt-get update
	sudo apt-get install -y certbot python-certbot-apache
	# Create cert
	sudo certbot --agree-tos --no-eff-email certonly --keep-until-expiring --webroot -w $tilecacheContentFolder/ --email $administratorEmail -d $tilecacheHostname -d a.${tilecacheHostname} -d b.${tilecacheHostname} -d c.${tilecacheHostname}
fi

# Enable the VirtualHost; this is done manually to ensure the ordering is correct
if ${tilecacheSSL} && [ ! -L /etc/apache2/sites-enabled/701-tile_ssl.conf ]; then
	ln -s ${vhSslConf} /etc/apache2/sites-enabled/701-tile_ssl.conf
fi

# Enable mod_headers, so that the Access-Control-Allow-Origin header is sent
a2enmod headers

# SSL is installed by default, but may need enabling which requires a restart
if ${tilecacheSSL} && ! apache2ctl -M | grep ssl_module > /dev/null 2>&1
then
    echo "#	Activating apache ssl"
    a2enmod ssl
fi

# Restart Apache
service apache2 restart

# Munin Node, which should be installed after all other software; see: https://www.digitalocean.com/community/tutorials/how-to-install-the-munin-monitoring-tool-on-ubuntu-14-04
apt-get install -y munin-node
apt-get install -y munin-plugins-extra
apt-get install -y libwww-perl
# See: http://munin-monitoring.org/wiki/munin-node-configure
munin-node-configure --suggest --shell | sh
/etc/init.d/munin-node restart
echo "Munin plugins enabled as follows:"
munin-node-configure --suggest

# Report completion
echo "#	Installing tilecache completed"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
