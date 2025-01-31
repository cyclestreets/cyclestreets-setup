#!/bin/bash
# Installs the Placeford demo site

### Stage 1 - general setup

echo "#	CycleStreets: install Placeford site"

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
    echo "#	The config file, ${configFile}, does not exist or is not executable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. $SCRIPTDIRECTORY/${configFile}

# Announce starting
echo "# Placeford site installation $(date)"

# Check the options
if [ -z "${placefordContentFolder}" -o -z "${placefordLogsFolder}" ]; then
    echo "#     The Placeford site options are not configured; abandoning installation."
    exit 1
fi

## Main body

# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Ensure that dependencies are present
apt-get -y install apache2 php

# Install path to content and go there
mkdir -p "${placefordContentFolder}"

# Make the folder group writable
chmod -R g+w "${placefordContentFolder}"

# Switch to it
cd "${placefordContentFolder}"

# Create/update the repository, ensuring that the files are owned by the CycleStreets user (but the checkout should use the current user's account - see http://stackoverflow.com/a/4597929/180733 )
${asCS} git config --global --add safe.directory "${placefordContentFolder}"
if [ ! -d "${placefordContentFolder}/.git" ]
then
	${asCS} git clone https://github.com/cyclestreets/placeford.git "${placefordContentFolder}/"
else
	${asCS} git pull
fi

# Make the repository writable to avoid permissions problems when manually editing
chmod -R g+w "${placefordContentFolder}"

# Enable mod_proxy
a2enmod proxy
a2enmod proxy_http

# Create the VirtualHost configs if they don't exist, and write in the configuration, then enable
vhConf=/etc/apache2/sites-available/placeford-subdomain.conf
if [ ! -f ${vhConf} ]; then
	cp -p .apache-vhost-subdomain.conf.template ${vhConf}
	sed -i "s|/path/to/files|${placefordContentFolder}|g" ${vhConf}
	sed -i "s|/path/to/logs|${placefordLogsFolder}|g" ${vhConf}
fi
if [ ! -L /etc/apache2/sites-enabled/930-placeford-subdomain.conf ]; then
    ln -s ${vhConf} /etc/apache2/sites-enabled/930-placeford-subdomain.conf
fi

vhConf=/etc/apache2/sites-available/placeford-proxied.conf
if [ ! -f ${vhConf} ]; then
	cp -p .apache-vhost-proxied.conf.template ${vhConf}
	sed -i "s|/path/to/files|${placefordContentFolder}|g" ${vhConf}
	sed -i "s|/path/to/logs|${placefordLogsFolder}|g" ${vhConf}
fi
if [ ! -L /etc/apache2/sites-enabled/931-placeford-proxied.conf ]; then
    ln -s ${vhConf} /etc/apache2/sites-enabled/931-placeford-proxied.conf
fi

# Reload apache
service apache2 reload

# Report completion
echo "#	Installing Placeford site completed"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
