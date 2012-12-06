#!/bin/bash
# Script to install CycleStreets routing data on Ubuntu
# Tested on 12.10 (View Ubuntu version using 'lsb_release -a')
# This script is idempotent - it can be safely re-run without destroying existing data


#!# Needs lockfile writing to prevent parallel running


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



# This bit was irdb.sh ('install routing database'), written out by the importer

# Define the import edition (i.e. the database name)
#!# Replace with a reader in the script section above
importEdition=routing121115
md5Tsv=43cac953ce99b44bb4a23347fca0653c
md5Tables=623950cc0a7e1a47c543d138e60be4bd


# Narrate
echo "#	Installing the routing database ${importEdition}."
date

echo "#	Installation - checking data integrity"
if [ "$(openssl dgst -md5 ${websitesBackupsFolder}/${importEdition}tsv.tar.gz)" != "MD5(${websitesBackupsFolder}/${importEdition}tsv.tar.gz)= ${md5Tsv}" ]; then
	echo "#	Tsv md5 does not match"
	exit 1
fi
if [ "$(openssl dgst -md5 ${websitesBackupsFolder}/${importEdition}tables.tar.gz)" != "MD5(${websitesBackupsFolder}/${importEdition}tables.tar.gz)= ${md5Tables}" ]; then
	echo "#	Tables md5 does not match"
	exit 1
fi

echo "#	Create the database and set default collation"
mysqladmin create ${importEdition} -hlocalhost -uroot -p${mysqlRootPassword} --default-character-set=utf8
mysql -hlocalhost -uroot -p${mysqlRootPassword} -e "alter database ${importEdition} collate utf8_unicode_ci;"

echo "# Load the procedures"
mysql ${importEdition} -hlocalhost -uroot -p${mysqlRootPassword} < /websites/www/content/documentation/schema/photosEnRoute.sql
mysql ${importEdition} -hlocalhost -uroot -p${mysqlRootPassword} < /websites/www/content/documentation/schema/nearestPoint.sql
date

echo "#	Unpack and install the tsv files."
sudo -u cyclestreets tar xf ${websitesBackupsFolder}/${importEdition}tsv.tar.gz -C /websites/www/content/

echo "#	Point current at new data:"
#!# Replace/add the new daemon config file mechanism
rm /websites/www/content/data/routing/current
sudo -u cyclestreets ln -s ${importEdition}/ /websites/www/content/data/routing/current

echo "#	Clean up the compressed tsv data."
rm ${websitesBackupsFolder}/${importEdition}tsv.tar.gz
date

echo "#	Installing the database tables"
echo "#	Unpack the tables, install and clean up."

# Check for the existence of the directory
#!# Hard-coded location /var/lib/mysql/
if [ ! -d /var/lib/mysql/${importEdition} ]; then
   echo "# The database doesn't not seem to be installed correctly." 1>&2
   exit 1
fi

# Unpack the database
tar x -C /websites/www/backups -pvf ${websitesBackupsFolder}/${importEdition}tables.tar.gz

# Remove the zip
rm -f ${websitesBackupsFolder}/${importEdition}tables.tar.gz

# Move the tables into mysql
mv ${websitesBackupsFolder}/${importEdition}/* /var/lib/mysql/${importEdition}

# Remove the empty folder
rmdir ${websitesBackupsFolder}/${importEdition}


date

echo "#	Install the optimized nearestPoint table"
mysql ${importEdition} -hlocalhost -uroot -p${mysqlRootPassword} -e "call createPathForNearestPoint();"

echo "#	Install the sieve"
sudo -u cyclestreets mv ${websitesBackupsFolder}/sieve.sql /websites/www/content/import/

echo "#	Building the photosEnRoute tables - but skipping the actual indexing"
mysql ${importEdition} -hlocalhost -uroot -p${mysqlRootPassword} -e "call indexPhotos(true,0);"

echo "#	Completed installation"
date





# This bit was installPhotoIndex.sh, written out by the importer

# Installing the photo index (this usually lags behind production of the main routing database by about an hour)
# If this script is present, run it. (It should self destruct and so not run un-necessarily.)




# Install photo index
#!# Some of these "sudo -u cyclestreets" are not required
sudo -u cyclestreets gunzip ${websitesBackupsFolder}/photoIndex.gz
#!# Fix this rename upstream
sudo -u cyclestreets mv ${websitesBackupsFolder}/photoIndex ${websitesBackupsFolder}/photoIndex.sql
mysql $importEdition -hlocalhost -uroot -p${mysqlRootPassword} < ${websitesBackupsFolder}/photoIndex.sql

# Clean up
rm ${websitesBackupsFolder}/photoIndex.sql


# Shell script files no longer actually used
#!# Remove writing of these upstream
rm ${websitesBackupsFolder}/installPhotoIndex.sh
rm ${websitesBackupsFolder}/irdb.sh



# Install using...
# ln -s /websites/www/content/configuration/backup/www/cyclestreetsHourly /etc/cron.hourly/cyclestreetsHourly
# Remove using...
# rm /etc/cron.hourly/cyclestreetsHourly

