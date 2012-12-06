#!/bin/bash
# Script to install CycleStreets routing data on Ubuntu
# Tested on 12.10 (View Ubuntu version using 'lsb_release -a')
# This script is idempotent - it can be safely re-run without destroying existing data

echo "#	CycleStreets routing data installation $(date)"

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#	This script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

### CREDENTIALS ###
# Name of the credentials file
configFile=../.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -e ./${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. ./${configFile}

# Logging
# Use an absolute path for the log file to be tolerant of the changing working directory in this script
setupLogFile=$(readlink -e $(dirname $0))/log.txt
touch ${setupLogFile}
echo "#	CycleStreets routing data installation in progress, follow log file with: tail -f ${setupLogFile}"
echo "#	CycleStreets routing data installation $(date)" >> ${setupLogFile}

# Ensure there is a cyclestreets user account
if [ ! id -u ${username} >/dev/null 2>&1 ]; then
	echo "#\User ${username} must exist: please run the main website install script"
	exit 1
fi

# Ensure the main website installation is present
if [ ! -d ${websitesContentFolder}/data/routing ]; then
	echo "#\The main website installation must exist: please run the main website install script"
	exit 1
fi



#	CycleStreets hourly tasks for www
# Installed using...
# ln -s /websites/www/content/configuration/backup/www/cyclestreetsHourly /etc/cron.hourly/cyclestreetsHourly
# Remove using...
# rm /etc/cron.hourly/cyclestreetsHourly

# Attempt to get the latest import
if [ -e "/websites/www/content/configuration/backup/www/getLatestImport.sh" ] 
then
#	Note the install should not run as root
sudo -u cyclestreets /websites/www/content/configuration/backup/www/getLatestImport.sh
fi

# If an import routing database install script is present, run it. (It should self destruct and so not run un-necessarily.)
if [ -e "/websites/www/backups/irdb.sh" ] 
then
#	Note the install should not run as root
sudo -u cyclestreets /websites/www/backups/irdb.sh
fi

# Installing the photo index (this usually lags behind production of the main routing database by about an hour)
# If this script is present, run it. (It should self destruct and so not run un-necessarily.)
if [ -e "/websites/www/backups/installPhotoIndex.sh" ] 
then
#	Note the install should not run as root (although it doesn't really matter in this case).
sudo -u cyclestreets /websites/www/backups/installPhotoIndex.sh
fi
