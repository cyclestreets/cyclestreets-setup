#!/bin/bash
# Installs the CyIPT server

### Stage 1 - general setup

echo "#	CycleStreets: install CyIPT server"

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

# Announce starting
echo "# CyIPT installation $(date)"


## Main body

# Clone the cyipt repo
if [ ! -d /opt/cyipt-deploy ]; then
        mkdir -p /opt/cyipt-deploy/
        chown cyclestreets.rollout /opt/cyipt-deploy && chmod g+ws /opt/cyipt-deploy
        su --login cyclestreets -c "git clone git@github.com:cyipt/cyipt-deploy.git /opt/cyipt-deploy"
        su --login cyclestreets -c "git config -f /opt/cyipt-deploy/.git/config core.sharedRepository group"
	cp -pr /opt/cyipt-deploy/.config.sh.template /opt/cyipt-deploy/.config.sh
	chmod +x /opt/cyipt-deploy/.config.sh
fi

# Install CyIPT website
source /opt/cyipt-deploy/run.sh

# Clone the ActDev UI repo
if [ ! -d /var/www/actdev-ui ]; then
	mkdir -p /var/www/actdev-ui/
	chown cyclestreets.rollout /var/www/actdev-ui && chmod g+ws /var/www/actdev-ui
	su --login cyclestreets -c "git clone git@github.com:cyipt/actdev-ui.git /var/www/actdev-ui"
	su --login cyclestreets -c "git config -f /var/www/actdev-ui/.git/config core.sharedRepository group"
	su --login cyipt -c 'git config --global --add safe.directory /var/www/actdev-ui'
fi

# Install the ActDev website
source /var/www/actdev-ui/install.sh


# Munin Node, which should be installed after all other software; see: https://www.digitalocean.com/community/tutorials/how-to-install-the-munin-monitoring-tool-on-ubuntu-14-04
# Include dependencies for Munin MySQL plugins; see: https://raymii.org/s/snippets/Munin-Fix-MySQL-Plugin-on-Ubuntu-12.04.html
apt-get install -y libcache-perl libcache-cache-perl
# Add libdbi-perl as otherwise /usr/share/munin/plugins/mysql_ suggest will show missing DBI.pm; see: http://stackoverflow.com/questions/20568836/cant-locate-dbi-pm and https://github.com/munin-monitoring/munin/issues/713
apt-get install -y libdbi-perl libdbd-mysql-perl
apt-get install -y libdbd-pg-perl
apt-get install -y munin-node
apt-get install -y munin-plugins-extra
apt-get install -y libwww-perl
# See: http://munin-monitoring.org/wiki/munin-node-configure
munin-node-configure --suggest --shell | sh
/etc/init.d/munin-node restart
echo "Munin plugins enabled as follows:"
munin-node-configure --suggest | true
ufw allow 4949
ufw reload


# Report completion
echo "#	Installing CyIPT completed"

# Remove the lock file - ${0##*/} extracts the script's basename
) 900>$lockdir/${0##*/}

# End of file
