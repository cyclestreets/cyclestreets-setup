#!/bin/bash
# Script to install CycleStreets routing data on Ubuntu
# Tested on 12.10 (View Ubuntu version using 'lsb_release -a')
# This script is idempotent - it can be safely re-run without destroying existing data


#!# Needs lockfile writing to prevent parallel running


### Stage 1 - general setup

echo "#	CycleStreets routing data installation $(date)"

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#	This script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

# Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 9 || { echo 'An installation is already running' ; exit 1; }


### CREDENTIALS ###
# Name of the credentials file
configFile=../.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -e ./${configFile} ]; then
    echo "# The config file, ${configFile}, does not exist - copy your own based on the ${configFile}.template file." 1>&2
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
	echo "# User ${username} must exist: please run the main website install script"
	exit 1
fi

# Ensure the main website installation is present
if [ ! -d ${websitesContentFolder}/data/routing -o ! -d $websitesBackupsFolder ]; then
	echo "# The main website installation must exist: please run the main website install script"
	exit 1
fi


### Stage 2 - obtain the routing import definition

# Ensure import machine and definition file variables has been defined
if [ -z "${importMachineAddress}" -o -z "${importMachineFile}" ]; then
	echo "# An import machine and definition file must be defined in order to run an import"
	exit 1
fi

# Retrieve the routing definition file from the import machine
set +e
sudo -u $username scp ${username}@${importMachineAddress}:${importMachineFile} ${websitesBackupsFolder} >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "# The import machine file could not be retrieved; please check the 'importMachineAddress' and 'importMachineFile' settings"
	exit 1
fi
set -e

# Get the required variables from the routing definition file; this is not directly executed for security
# Sed extraction method as at http://stackoverflow.com/a/1247828/180733
timestamp=`sed -n                       's/^timestamp\s*=\s*\([0-9]*\)\s*$/\1/p'       $importMachineFile`
importEdition=`sed -n               's/^importEdition\s*=\s*\([0-9a-zA-Z]*\)\s*$/\1/p' $importMachineFile`
md5Tsv=`sed -n                             's/^md5Tsv\s*=\s*\([0-9a-f]*\)\s*$/\1/p'    $importMachineFile`
md5Tables=`sed -n                       's/^md5Tables\s*=\s*\([0-9a-f]*\)\s*$/\1/p'    $importMachineFile`
importStartHourFirst=`sed -n 's/^importStartHourFirst\s*=\s*\([0-9]*\)\s*$/\1/p'       $importMachineFile`
importStartHourLast=`sed -n   's/^importStartHourLast\s*=\s*\([0-9]*\)\s*$/\1/p'       $importMachineFile`

# Ensure the key variables are specified
if [ -z "$timestamp" -o -z "$importEdition" -o -z "$md5Tsv" -o -z "$md5Tables" ]; then
	echo "# The routing definition file does not contain all of timestamp,importEdition,md5Tsv,md5Tables"
	exit 1
fi

# If specified, only allow this script to run between the specified times as the download can be large and disrupt main site performance
if [ -n "$importStartHourLast" -a -n "$importStartHourFirst" ]; then
	hour=$(date +%H)
	if [ $hour -gt $importStartHourLast -o $hour -lt $importStartHourFirst ]; then
		echo "# The specified import machine only permits downloads between ${importStartHourFirst}:00 and ${importStartHourLast}:59, to avoid disrupting main site performance"
		exit
	fi
fi

#!# Need to add a check here if the specified import has already been used, by reading the actual database


### Stage 3 - get the routing files and check data integrity

# Begin the file transfer
echo "#	Transferring the routing files from the import machine ${importMachineAddress}:"

# TSV file
echo "#	Transfer the TSV file"
sudo -u $username scp ${username}@${importMachineAddress}:${websitesBackupsFolder}/${importEdition}tsv.tar.gz ${websitesBackupsFolder}/
date

# Hot-copied tables file
echo "#	Transfer the hot copied tables file"
sudo -u $username scp ${username}@${importMachineAddress}:${websitesBackupsFolder}/${importEdition}tables.tar.gz ${websitesBackupsFolder}/
date

# Sieve file
#!# This is in a different place and could presumably be out-of-sync
echo "#	Transfer the sieve"
sudo -u $username scp ${username}@${importMachineAddress}:${websitesContentFolder}/import/sieve.sql ${websitesBackupsFolder}/

# Photos index and installer file
echo "#	File transfer stage complete"
sudo -u $username scp ${username}@${importMachineAddress}:${websitesBackupsFolder}/photoIndex.gz ${websitesBackupsFolder}/

echo "#	Checking data integrity"
if [ "$(openssl dgst -md5 ${websitesBackupsFolder}/${importEdition}tsv.tar.gz)" != "MD5(${websitesBackupsFolder}/${importEdition}tsv.tar.gz)= ${md5Tsv}" ]; then
	echo "#	TSV md5 does not match"
	exit 1
fi
if [ "$(openssl dgst -md5 ${websitesBackupsFolder}/${importEdition}tables.tar.gz)" != "MD5(${websitesBackupsFolder}/${importEdition}tables.tar.gz)= ${md5Tables}" ]; then
	echo "#	Tables md5 does not match"
	exit 1
fi


### Stage 4 - unpack and install the TSV files

echo "#	Unpack and install the TSV files"
sudo -u $username tar xf ${websitesBackupsFolder}/${importEdition}tsv.tar.gz -C ${websitesContentFolder}/

echo "#	Point current at new data"
#!# Replace/add the new daemon config file mechanism
if [ -L ${websitesContentFolder}/data/routing/current ]; then
	rm ${websitesContentFolder}/data/routing/current
fi
sudo -u $username ln -s ${importEdition}/ ${websitesContentFolder}/data/routing/current

echo "#	Clean up the compressed TSV data"
rm ${websitesBackupsFolder}/${importEdition}tsv.tar.gz
date


### Stage 5 - create the routing database

# Narrate
echo "#	Installing the routing database ${importEdition}."
date

echo "#	Create the database (which will be empty for now) and set default collation"
mysqladmin create ${importEdition} -hlocalhost -uroot -p${mysqlRootPassword} --default-character-set=utf8
mysql -hlocalhost -uroot -p${mysqlRootPassword} -e "ALTER DATABASE ${importEdition} COLLATE utf8_unicode_ci;"

# Ensure the MySQL directory has been created
#!# Hard-coded location /var/lib/mysql/
if [ ! -d /var/lib/mysql/${importEdition} ]; then
   echo "# The database does not seem to be installed correctly." 1>&2
   exit 1
fi

# Unpack the database files; options here are "tar extract, change directory to websitesBackupsFolder, preserve permissions, verbose, file is routingXXXXXXtables.tar.gz
sudo -u $username tar x -C ${websitesBackupsFolder} -pvf ${websitesBackupsFolder}/${importEdition}tables.tar.gz

# Remove the zip
rm -f ${websitesBackupsFolder}/${importEdition}tables.tar.gz

# Move the tables into mysql
mv ${websitesBackupsFolder}/${importEdition}/* /var/lib/mysql/${importEdition}

# Ensure the permissions are correct
chown -R mysql.mysql /var/lib/mysql/${importEdition}

# Remove the empty folder
rmdir ${websitesBackupsFolder}/${importEdition}


### Stage 6 - move the seive into place for the purposes of having visible documentation

echo "#	Install the sieve"
sudo -u $username mv ${websitesBackupsFolder}/sieve.sql ${websitesContentFolder}/import/


### Stage 7 - run post-install stored procedures for nearestPoint

echo "#	Install and run the optimized nearestPoint table"
mysql ${importEdition} -hlocalhost -uroot -p${mysqlRootPassword} < ${websitesContentFolder}/documentation/schema/nearestPoint.sql
mysql ${importEdition} -hlocalhost -uroot -p${mysqlRootPassword} -e "CALL createPathForNearestPoint();"


### Stage 8 - deal with photos-en-route

# Installing the photo index (this usually lags behind production of the main routing database by about an hour)
echo "#	Building the photosEnRoute tables"
mysql ${importEdition} -hlocalhost -uroot -p${mysqlRootPassword} < ${websitesContentFolder}/documentation/schema/photosEnRoute.sql
#!# Not clear why this comes before installing the photo index?
mysql ${importEdition} -hlocalhost -uroot -p${mysqlRootPassword} -e "CALL indexPhotos(true,0);"

# Install photo index
sudo -u $username gunzip ${websitesBackupsFolder}/photoIndex.gz
#!# Fix this rename upstream
sudo -u $username mv ${websitesBackupsFolder}/photoIndex ${websitesBackupsFolder}/photoIndex.sql
mysql $importEdition -hlocalhost -uroot -p${mysqlRootPassword} < ${websitesBackupsFolder}/photoIndex.sql
rm ${websitesBackupsFolder}/photoIndex.sql


### Stage 9 - update the map_config entry to switch to the new routing data, and restart the daemon

#!# Todo


### Stage 10 - remove the import definition file

echo "# Removing the import definition file"
rm ${importMachineFile}


### Stage 11 - install the cron job for future updating

#!# Todo
# ln -s /websites/www/content/configuration/backup/www/cyclestreetsHourly /etc/cron.hourly/cyclestreetsHourly



### Stage 12 - end

# Finish
date
echo "All done"

# Remove the lock file
) 9>/var/lock/cyclestreetsimport


