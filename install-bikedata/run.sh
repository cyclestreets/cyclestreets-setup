#!/bin/bash
# Installs the Bikedata website

### Stage 1 - general setup

echo "#	CycleStreets: install Bikedata website"

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
echo "# Bikedata website installation $(date)"

# Check the options
if [ -z "${bikedataContentFolder}" -o -z "${bikedataLogsFolder}" ]; then
    echo "#     The Bikedata website options are not configured; abandoning installation."
    exit 1
fi

## Main body

# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Ensure that dependencies are present
apt-get -y install apache2 php

# Install path to content and go there
mkdir -p "${bikedataContentFolder}"

# Make the folder group writable
chmod -R g+w "${bikedataContentFolder}"

# Switch to it
cd "${bikedataContentFolder}"

# Create/update the repository, ensuring that the files are owned by the CycleStreets user (but the checkout should use the current user's account - see http://stackoverflow.com/a/4597929/180733 )
if [ ! -d "${bikedataContentFolder}/.git" ]
then
	${asCS} git clone https://github.com/cyclestreets/bikedata.git "${bikedataContentFolder}/"
else
	${asCS} git -C "${bikedataContentFolder}" pull
fi

# Make the repository writable to avoid permissions problems when manually editing
chmod -R g+w "${bikedataContentFolder}"

# Add dependencies
cd "${bikedataContentFolder}"
yarn install

# Create the VirtualHost config if it doesn't exist, and write in the configuration
vhConf=/etc/apache2/sites-available/bikedata.conf
if [ ! -f ${vhConf} ]; then
	cp -p .apache-vhost.conf.template ${vhConf}
	sed -i "s|/var/www/bikedata|${bikedataContentFolder}|g" ${vhConf}
	sed -i "s|/var/log/apache2|${bikedataLogsFolder}|g" ${vhConf}
fi

# Enable the VirtualHost; this is done manually to ensure the ordering is correct
if [ ! -L /etc/apache2/sites-enabled/650-bikedata.conf ]; then
    ln -s ${vhConf} /etc/apache2/sites-enabled/650-bikedata.conf
fi

# Reload apache
service apache2 reload

# Add cronjob to update from Git regularly
cp -pr $SCRIPTDIRECTORY/bikedata.cron /etc/cron.d/bikedata
sed -i "s|/var/www/bikedata|${bikedataContentFolder}|g" /etc/cron.d/bikedata
chown root.root /etc/cron.d/bikedata
chmod 644 /etc/cron.d/bikedata

# Report completion
echo "#	Installing Bikedata website completed"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
