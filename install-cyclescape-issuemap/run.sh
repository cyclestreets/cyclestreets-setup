#!/bin/bash
# Installs the Cyclescape issuemap website

### Stage 1 - general setup

echo "#	CycleStreets: install Cyclescape issuemap website"

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
    echo "#	The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. $SCRIPTDIRECTORY/${configFile}

# Announce starting
echo "# Cyclescape issuemap website installation $(date)"

# Check the options
if [ -z "${cyclescapeissuemapContentFolder}" -o -z "${cyclescapeissuemapLogsFolder}" ]; then
    echo "#     The Cyclescape issuemap website options are not configured; abandoning installation."
    exit 1
fi

## Main body

# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Ensure that dependencies are present
apt-get -y install apache2 php

# Install path to content and go there
mkdir -p "${cyclescapeissuemapContentFolder}"

# Make the folder group writable
chmod -R g+w "${cyclescapeissuemapContentFolder}"

# Switch to it
cd "${cyclescapeissuemapContentFolder}"

# Create/update the repository, ensuring that the files are owned by the CycleStreets user (but the checkout should use the current user's account - see http://stackoverflow.com/a/4597929/180733 )
if [ ! -d "${cyclescapeissuemapContentFolder}/.git" ]
then
	${asCS} git clone https://github.com/cyclestreets/cyclescape-issuemap.git "${cyclescapeissuemapContentFolder}/"
else
	${asCS} git pull
fi

# Make the repository writable to avoid permissions problems when manually editing
chmod -R g+w "${cyclescapeissuemapContentFolder}"

# Create the VirtualHost config if it doesn't exist, and write in the configuration
vhConf=/etc/apache2/sites-available/cyclescape-issuemap.conf
if [ ! -f ${vhConf} ]; then
	cp -p .apache-vhost.conf.template ${vhConf}
	sed -i "s|/var/www/cyclescape-issuemap|${cyclescapeissuemapContentFolder}|g" ${vhConf}
	sed -i "s|/var/log/apache2|${cyclescapeissuemapLogsFolder}|g" ${vhConf}
fi

# Enable the VirtualHost; this is done manually to ensure the ordering is correct
if [ ! -L /etc/apache2/sites-enabled/625-cyclescape-issuemap.conf ]; then
    ln -s ${vhConf} /etc/apache2/sites-enabled/625-cyclescape-issuemap.conf
fi

# Reload apache
service apache2 reload

# Add cronjob to update from Git regularly
cp -pr $SCRIPTDIRECTORY/cyclescape-issuemap.cron /etc/cron.d/cyclescape-issuemap
sed -i "s|/var/www/cyclescape-issuemap|${cyclescapeissuemapContentFolder}|g" /etc/cron.d/cyclescape-issuemap

# Report completion
echo "#	Installing Cyclescape issuemap website completed"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
