#!/bin/bash
# Installs the backup system
## This script is idempotent - it can be safely re-run without destroying existing data

## General setup

echo "#	CycleStreets: install/update backup system"

### Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#     This script must be run as root." 1>&2
    exit 1
fi

### Bomb out if something goes wrong
set -e

### Lock directory
lockdir=/var/lock/cyclestreets_outer
mkdir -p $lockdir

### Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 900 || { echo '#	An installation is already running' ; exit 1; }


### DEFAULTS ###

# Exim email
# Basically, use the 'internet' (direct delivery) mode here for a developer setup
#!# Simplify this block to be a single setting like profile='developer'/'deployment' and write out settings (based on those below) accordingly
dc_eximconfig_configtype='internet'  # Use 'internet' for direct delivery, or 'satellite' if mail is delivered by your ISP
dc_local_interfaces=''               # Use '' if using 'internet' or '127.0.0.1' if using 'satellite' above
dc_readhost='cyclestreets.net'       # Set to 'cyclestreets.net'
dc_smarthost=''                      # Use '' if using 'internet' or 'mx.yourispmailhost.com' if using 'satellite' above


## CREDENTIALS

### Get the script directory see: http://stackoverflow.com/a/246128/180733
### The multi-line method of geting the script directory is needed to enable the script to be called from elsewhere.
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

### Use this to remove the ../ to get the repository root; assumes the script is always down one level
ScriptHome=$(readlink -f "${SCRIPTDIRECTORY}/..")

### Define the location of the credentials file relative to script directory
configFile=$ScriptHome/.config.sh

### Generate your own credentials file by copying from .config.sh.template
if [ ! -x $configFile ]; then
    echo "#	The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

### Load the credentials
. $configFile


## Main body

### Announce starting
echo "# Backup system installation $(date)"

## System Update

### Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

### Installer
[[ $baseOS = "Ubuntu" ]] && packageInstall="apt -y install" || packageInstall="brew install"
[[ $baseOS = "Ubuntu" ]] && packageUpdate="apt update" || packageUpdate="brew update"

### Prepare the apt index; it may be practically non-existent on a fresh VM
$packageUpdate > /dev/null

### Bring the machine distribution up to date by updating all existing packages
apt -y upgrade
apt -y dist-upgrade
apt -y autoremove
$packageInstall update-manager-core

### Ensure locale
$packageInstall language-pack-en-base


## Email / exim

### Add Exim, so that mail will be sent, and add its configuration, but firstly backing up the original exim distribution config file if not already done
if [ "$configureExim" = true ]; then
    ### NB The config here is currently Debian/Ubuntu-specific
    $packageInstall exim4
    if [ ! -e /etc/exim4/update-exim4.conf.conf.original ]; then
	cp -pr /etc/exim4/update-exim4.conf.conf /etc/exim4/update-exim4.conf.conf.original
    fi
    ### NB These will deliberately overwrite any existing config; it is assumed that once set, the config will only be changed via this setup script (as otherwise it is painful during testing)
    sed -i "s/dc_eximconfig_configtype=.*/dc_eximconfig_configtype='${dc_eximconfig_configtype}'/" /etc/exim4/update-exim4.conf.conf
    sed -i "s/dc_local_interfaces=.*/dc_local_interfaces='${dc_local_interfaces}'/" /etc/exim4/update-exim4.conf.conf
    sed -i "s/dc_readhost=.*/dc_readhost='${dc_readhost}'/" /etc/exim4/update-exim4.conf.conf
    sed -i "s/dc_smarthost=.*/dc_smarthost='${dc_smarthost}'/" /etc/exim4/update-exim4.conf.conf
    ### NB These two are the same in any CycleStreets installation but different from the default Debian installation:
    sed -i "s/dc_other_hostnames=.*/dc_other_hostnames=''/" /etc/exim4/update-exim4.conf.conf
    sed -i "s/dc_hide_mailname=.*/dc_hide_mailname='true'/" /etc/exim4/update-exim4.conf.conf
    systemctl restart exim4
fi


## Backup system

### Establish a location for backups to go
mkdir -p /websites

### Make them writable
chown ${username}.${rollout} /websites

### setgid so that the group of new files is rollout
chmod g+s /websites

## Daily cron
cronLink=/etc/cron.d/cyclestreets
cronTarget=/opt/configurations/backup/etc/cron.d/cyclestreets

### Setup link to cron if doesn't exist
if [ ! -L ${cronLink} ]; then
    ln -s ${cronTarget} ${cronLink}
fi

### Cron jobs require specific ownership and permissions to run
chown root ${cronTarget}
chmod go-w ${cronTarget}


## Munin Node, which should be installed after all other software
$packageInstall munin-node

### See: http://munin-monitoring.org/wiki/munin-node-configure
munin-node-configure --suggest --shell | sh

### Add access to munin data from dev.cyclestreets.net
muninNodeConf=/etc/munin/munin-node.conf
### Avoid re-adding
if ! grep -q "Access from CycleStreets dev machine" ${muninNodeConf}; then
    cat >> ${muninNodeConf} << EOF

# Added by cyclestreets-setup/install-backup
# Access from CycleStreets dev machine
allow ^dev\.cyclestreets\.net$
allow ^93\.93\.128\.92$
allow ^46\.235\.226\.213$

EOF
fi

### Restart munin-node
systemctl restart munin-node


## Report completion
echo "#	Installing backup system completed"

### Remove the lock file - ${0##*/} extracts the script's basename
) 900>$lockdir/${0##*/}

# End of file
