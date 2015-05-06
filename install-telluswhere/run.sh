#!/bin/bash
# Installs a telluswhere site

### Stage 1 - general setup

echo "#	CycleStreets: install a telluswhere site"

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
echo "# Telluswhere site installation $(date)"

# Check the options
if [ -z "${telluswhereContentFolder}" -o -z "${telluswhereLogsFolder}" ]; then
    echo "#     The telluswhere site options are not configured; abandoning installation."
    exit 1
fi

## Main body

# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Ensure that dependencies are present; GD is needed for thumbnailing
apt-get -y install apache2 php5
apt-get -y install php5-gd

# Install path to content and go there
mkdir -p "${telluswhereContentFolder}"

# Make the folder group writable
chmod -R g+w "${telluswhereContentFolder}"

# Switch to it
cd "${telluswhereContentFolder}"

# Create/update the repository, ensuring that the files are owned by the CycleStreets user (but the checkout should use the current user's account - see http://stackoverflow.com/a/4597929/180733 )
# #!# Repo is currently private so this stage will fail; as a workaround, clone the repo manually first as a user which has access
# if [ ! -d "${telluswhereContentFolder}/.git" ]
# then
# 	${asCS} git clone git://github.com/cyclestreets/telluswhere.git "${telluswhereContentFolder}/"
# else
# 	${asCS} git pull
# fi

# Make the repository writable to avoid permissions problems when manually editing
chmod -R g+w "${telluswhereContentFolder}"

# Add writability for areas requiring it
sudo chown -R www-data tmp/
sudo chown -R www-data db/
sudo chown -R www-data images/news/

# Create the VirtualHost config if it doesn't exist, and write in the configuration
vhConf=/etc/apache2/sites-available/telluswhere.conf
if [ ! -f ${vhConf} ]; then
	cp -p .apache-vhost.conf.template ${vhConf}
	sed -i "s|/path/to/files|${telluswhereContentFolder}|g" ${vhConf}
	sed -i "s|/path/to/logs|${telluswhereLogsFolder}|g" ${vhConf}
fi

# Enable the VirtualHost; this is done manually to ensure the ordering is correct
if [ ! -L /etc/apache2/sites-enabled/600-telluswhere.conf ]; then
    ln -s ${vhConf} /etc/apache2/sites-enabled/600-telluswhere.conf
fi

# Add support for SQLite, and add client program
apt-get -y install php5-sqlite
apt-get -y install sqlite3

# Reload apache
service apache2 reload

# Report completion
echo "#	Installing telluswhere site completed"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
