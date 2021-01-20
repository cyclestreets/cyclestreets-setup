#!/bin/bash
# Installs the Microsites

### Stage 1 - general setup

echo "#	CycleStreets: install Microsites"

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#     This script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

# Lock directory
lockdir=/var/lock/cyclestreets_outer
mkdir -p $lockdir

# Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 900 || { echo '#	An installation is already running' ; exit 1; }


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

# Use this to remove the ../ to get the repository root; assumes the script is always down one level
ScriptHome=$(readlink -f "${SCRIPTDIRECTORY}/..")

# Define the location of the credentials file relative to script directory
configFile=$ScriptHome/.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x $configFile ]; then
    echo "#	The config file, ${configFile}, does not exist or is not executable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. $configFile

# Announce starting
echo "# Microsites installation $(date)"


## Main body

# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Install base webserver software
. $ScriptHome/utility/installBaseWebserver.sh


# Install mobile website
mobilewebContentFolder=/websites/mobileweb/content
mobilewebLogsFolder=/websites/www/logs
. $ScriptHome/install-mobileweb/run.sh

# Install Bikedata website
bikedataContentFolder=/websites/bikedata/content
bikedataLogsFolder=/websites/www/logs
. $ScriptHome/install-bikedata/run.sh

# Install Telluswhere websites
telluswhereContentFolder=/websites/telluswhere/content
telluswhereLogsFolder=/websites/www/logs
. $ScriptHome/install-telluswhere/run.sh

# Install Cyclescape issuemap website
cyclescapeissuemapContentFolder=/websites/cyclescape-issuemap/content
cyclescapeissuemapLogsFolder=/websites/www/logs
. $ScriptHome/install-cyclescape-issuemap/run.sh

# Install Placeford site
placefordContentFolder=/websites/placeford/content
placefordLogsFolder=/websites/www/logs
. $ScriptHome/install-placeford/run.sh

# Install transporthack site
transporthackContentFolder=/websites/transporthack/content
transporthackLogsFolder=/websites/www/logs
. $ScriptHome/install-transporthack/run.sh

# Install Cyclescape blog
. $ScriptHome/install-blog/run.sh

# Enable mod_proxy_html for proxy installations
a2enmod proxy_html
a2enmod xml2enc
a2enmod headers
apt-get install -y libxml2-dev
service apache2 restart


# Munin Node, which should be installed after all other software; see: https://www.digitalocean.com/community/tutorials/how-to-install-the-munin-monitoring-tool-on-ubuntu-14-04
# Include dependencies for Munin MySQL plugins; see: https://raymii.org/s/snippets/Munin-Fix-MySQL-Plugin-on-Ubuntu-12.04.html
apt-get install -y libcache-perl libcache-cache-perl
# Add libdbi-perl as otherwise /usr/share/munin/plugins/mysql_ suggest will show missing DBI.pm; see: http://stackoverflow.com/questions/20568836/cant-locate-dbi-pm and https://github.com/munin-monitoring/munin/issues/713
apt-get install -y libdbi-perl libdbd-mysql-perl
apt-get install -y munin-node
apt-get install -y munin-plugins-extra
apt-get install -y libwww-perl
# See: http://munin-monitoring.org/wiki/munin-node-configure
munin-node-configure --suggest --shell | sh
/etc/init.d/munin-node restart
echo "Munin plugins enabled as follows:"
munin-node-configure --suggest



# Report completion
echo "#	Installing Microsites completed"

# Remove the lock file - ${0##*/} extracts the script's basename
) 900>$lockdir/${0##*/}

# End of file
