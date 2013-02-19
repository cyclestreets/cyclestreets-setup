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

# Logging
# Use an absolute path for the log file to be tolerant of the changing working directory in this script
setupLogFile=$SCRIPTDIRECTORY/log.txt
touch ${setupLogFile}
echo "# Tilecache installation in progress, follow log file with: tail -f ${setupLogFile}"
echo "# Tilecache installation $(date)" >> ${setupLogFile}


## Main body

# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Ensure that dependencies are present
apt-get -y install apache2 php5 >> ${setupLogFile}

# Install path to content and go there
${asCS} mkdir -p "${tilecacheContentFolder}"
cd "${tilecacheContentFolder}"

# Make sure the webserver user can write to the tilecache, by setting this as the owner
#!# The group name should be a setting
chown -R www-data.rollout "${tilecacheContentFolder}"
chmod -R g+w "${tilecacheContentFolder}"

# Create/update the tilecache repository, ensuring that the files are owned by the CycleStreets user (but the checkout should use the current user's account - see http://stackoverflow.com/a/4597929/180733 )
if [ ! -d "${tilecacheContentFolder}/.git" ]
then
	${asCS} git clone git://github.com/cyclestreets/tilecache.git "${tilecacheContentFolder}/"
else
	${asCS} git pull
fi

# Make the repository writable to avoid permissions problems when manually editing
chmod -R g+w "${tilecacheContentFolder}"

# Create the config file if it doesn't exist, and write in the configuration
if [ ! -f "${tilecacheContentFolder}/.config.php" ]; then
	${asCS} cp -pr .config.php.template .config.php
	sed -i "s|<cloudmadekey>|${tilecacheKeyCloudmade}|g" .config.php
fi

# Create the VirtualHost config if it doesn't exist, and write in the configuration
if [ ! -f ${websitesContentFolder}/configuration/apache/sites-available/tile ]; then
	cp -pr .apache-vhost.conf.template /etc/apache2/sites-available/tile
	sed -i "s|tile.example.com|${tilecacheUrl}|g" /etc/apache2/sites-available/tile
	sed -i "s|/path/to/files|${tilecacheContentFolder}|g" /etc/apache2/sites-available/tile
	sed -i "s|/path/to/logs|${websitesLogsFolder}|g" /etc/apache2/sites-available/tile
fi

# Enable the VirtualHost; this is done manually to ensure the ordering is correct
if [ ! -L /etc/apache2/sites-enabled/700-tile ]; then
    ln -s ${websitesContentFolder}/configuration/apache/sites-available/tile /etc/apache2/sites-enabled/700-tile
fi

# Enable mod_headers, so that the Access-Control-Allow-Origin header is sent
a2enmod headers

# Reload apache
service apache2 reload >> ${setupLogFile}


# Report completion
echo "#	Installing tilecache completed"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
