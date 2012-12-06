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



# Attempt to get the latest import



# Only allow this script to run in the small hours as the download can be large and disrupt main site performance.
hour=$(date +%H)
if [ $hour -gt 4 -o $hour -lt 1 ]
then
exit
fi

# This file identifies the import transfer script
filename=xfer.sh

# Full path
filepath=${websitesBackupsFolder}/${filename}

# Get the last modified date of the current transfer script
if [ -e ${filepath} ]
then
    lastMod=$(date -r ${filepath} +%s)
else
    lastMod=0
fi

# This test checks:
# 1. Whether the filepath exists
# 2. That it has size > 0
# 3. That it is newer than $lastMod
test="test -e ${filepath} -a \$(stat -c%s ${filepath}) -gt 0 -a \$(date -r ${filepath} +%s) -gt ${lastMod}"

# Temporarily turn off break-on-error to run the following test
set +e

# Run the test - which will set $? to zero if it succeeds. Other values indicate failure or error.
result=$(ssh ${importMachine} ${test})

# If the test succeeds, then check the second part
if [ ! $? = 0 ]
then
    echo "#	Skipping: No newer import available."
    exit
fi

# Resume break-on-error
set -e

# Download
echo "#	Downloading new version"
scp ${importMachine}:${filepath} ${websitesBackupsFolder}/

# Make sure it is executable
chmod a+x ${filepath}

# Run the script, which will start the transfer
${filepath}








# If an import routing database install script is present, run it. (It should self destruct and so not run un-necessarily.)
if [ -e "/websites/www/backups/irdb.sh" ]
then
	sudo -u cyclestreets /websites/www/backups/irdb.sh
fi


# This bit was installPhotoIndex.sh, written out by the importer

# Installing the photo index (this usually lags behind production of the main routing database by about an hour)
# If this script is present, run it. (It should self destruct and so not run un-necessarily.)


importEdition=routing121115


# Install photo index
gunzip < /websites/www/backups/photoIndex.gz | mysql $importEdition -hlocalhost -uroot -p${mysqlRootPassword}

# Clean up
rm /websites/www/backups/installPhotoIndex.sh
rm /websites/www/backups/photoIndex.gz



# Install using...
# ln -s /websites/www/content/configuration/backup/www/cyclestreetsHourly /etc/cron.hourly/cyclestreetsHourly
# Remove using...
# rm /etc/cron.hourly/cyclestreetsHourly

