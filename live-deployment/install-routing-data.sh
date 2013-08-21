#!/bin/bash
# Script to install CycleStreets routing data
# Tested on Ubuntu 12.10 (View Ubuntu version using 'lsb_release -a')
# This script is idempotent - it can be safely re-run without destroying existing data

# Requires password-less access to the import machine.

# When in failover mode uncomment the next two lines:
#echo "# Skipping in failover mode"
#exit 1

### Stage 1 - general setup

# Avoid echo if possible as this generates cron emails
# echo "#	CycleStreets routing data installation $(date)"

# Ensure this script is NOT run as root (it should be run as the cyclestreets user, having sudo rights as setup by install-website)
if [ "$(id -u)" = "0" ]; then
    echo "#	This script must NOT be run as root." 1>&2
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
setupLogFile=$(readlink -e $(dirname $0))/log.txt
touch ${setupLogFile}

# Avoid echo if possible as this generates cron emails
# echo "#	CycleStreets routing data installation in progress, follow log file with: tail -f ${setupLogFile}"
echo "$(date)	CycleStreets routing data installation" >> ${setupLogFile}

# Ensure there is a cyclestreets user account
if [ ! id -u ${username} >/dev/null 2>&1 ]; then
	echo "# User ${username} must exist: please run the main website install script" >> ${setupLogFile}
	exit 1
fi

# Ensure the main website installation is present
if [ ! -d ${websitesContentFolder}/data/routing -o ! -d $websitesBackupsFolder ]; then
	echo "# The main website installation must exist: please run the main website install script" >> ${setupLogFile}
	exit 1
fi


### Stage 2 - obtain the routing import definition

# Ensure import machine and definition file variables has been defined
if [ -z "${importMachineAddress}" -o -z "${importMachineFile}" ]; then
	echo "# An import machine and definition file must be defined in order to run an import" >> ${setupLogFile}
	exit 1
fi

# Retrieve the routing definition file from the import machine
set +e
scp ${username}@${importMachineAddress}:${importMachineFile} ${websitesBackupsFolder} >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo "#	The import machine file could not be retrieved; please check the 'importMachineAddress': ${importMachineAddress} and 'importMachineFile': ${importMachineFile} settings." >> ${setupLogFile}
	exit 1
fi
set -e

# Get the required variables from the routing definition file; this is not directly executed for security
# Sed extraction method as at http://stackoverflow.com/a/1247828/180733
# NB the timestamp parameter is not really used yet in the script below
# !! Note: the md5Dump option (which loads the database from a mysqldump generated file, and is an alternative to the hotcopy option md5Tables) is not yet supported
timestamp=`sed -n                       's/^timestamp\s*=\s*\([0-9]*\)\s*$/\1/p'       $importMachineFile`
importEdition=`sed -n               's/^importEdition\s*=\s*\([0-9a-zA-Z]*\)\s*$/\1/p' $importMachineFile`
md5Tsv=`sed -n                             's/^md5Tsv\s*=\s*\([0-9a-f]*\)\s*$/\1/p'    $importMachineFile`
md5Tables=`sed -n                       's/^md5Tables\s*=\s*\([0-9a-f]*\)\s*$/\1/p'    $importMachineFile`

# Ensure the key variables are specified
if [ -z "$timestamp" -o -z "$importEdition" -o -z "$md5Tsv" -o -z "$md5Tables" ]; then
	echo "# The routing definition file does not contain all of timestamp,importEdition,md5Tsv,md5Tables" >> ${setupLogFile}
	exit 1
fi

# Check to see if this routing database already exists
# !! Note: This line will appear to give an error such as: ERROR 1049 (42000) at line 1: Unknown database 'routing130701'
# but in fact that is the condition desired.
if mysql -hlocalhost -uroot -p${mysqlRootPassword} -e "use ${importEdition}"; then
	echo "#	Stopping because the routing database ${importEdition} already exists." >> ${setupLogFile}
	exit 1
fi

# Check to see if a routing data file for this routing edition already exists
if [ -d "${websitesContentFolder}/data/routing/${importEdition}" ]; then
	echo "#	Stopping because the routing data folder ${importEdition} already exists." >> ${setupLogFile}
	exit 1
fi


### Stage 3 - get the routing files and check data integrity

# Begin the file transfer
echo "$(date)	Transferring the routing files from the import machine ${importMachineAddress}" >> ${setupLogFile}

#	Transfer the TSV file
scp ${username}@${importMachineAddress}:${websitesBackupsFolder}/${importEdition}tsv.tar.gz ${websitesBackupsFolder}/

#	Hot-copied tables file
scp ${username}@${importMachineAddress}:${websitesBackupsFolder}/${importEdition}tables.tar.gz ${websitesBackupsFolder}/


# Sieve file
#!# This is in a different source folder and could presumably be out-of-sync; fix upstream to put with the routing files
scp ${username}@${importMachineAddress}:${websitesContentFolder}/import/sieve.sql ${websitesBackupsFolder}/

#	Note that all files are downloaded
echo "$(date)	File transfer stage complete" >> ${setupLogFile}

# MD5 checks
if [ "$(openssl dgst -md5 ${websitesBackupsFolder}/${importEdition}tsv.tar.gz)" != "MD5(${websitesBackupsFolder}/${importEdition}tsv.tar.gz)= ${md5Tsv}" ]; then
	echo "#	Stopping: TSV md5 does not match" >> ${setupLogFile}
	exit 1
fi
if [ "$(openssl dgst -md5 ${websitesBackupsFolder}/${importEdition}tables.tar.gz)" != "MD5(${websitesBackupsFolder}/${importEdition}tables.tar.gz)= ${md5Tables}" ]; then
	echo "#	Stopping: Tables md5 does not match" >> ${setupLogFile}
	exit 1
fi


### Stage 4 - unpack and install the TSV files
#	Unpack and install the TSV files
tar xf ${websitesBackupsFolder}/${importEdition}tsv.tar.gz -C ${websitesContentFolder}/

#	Clean up the compressed TSV data
rm ${websitesBackupsFolder}/${importEdition}tsv.tar.gz


### Stage 5 - create the routing database

# Narrate
echo "$(date)	Installing the routing database: ${importEdition}" >> ${setupLogFile}

#	Create the database (which will be empty for now) and set default collation
mysqladmin create ${importEdition} -hlocalhost -uroot -p${mysqlRootPassword} --default-character-set=utf8
mysql -hlocalhost -uroot -p${mysqlRootPassword} -e "ALTER DATABASE ${importEdition} COLLATE utf8_unicode_ci;"

# Ensure the MySQL directory has been created
# Requires root permissions to check this and so sudo is used.
#!# Hard-coded location /var/lib/mysql/
echo $password | sudo -S test -d /var/lib/mysql/${importEdition}
if [ $? != 0 ]; then
   echo "$(date) The database does not seem to be installed correctly." >> ${setupLogFile}
   exit 1
fi

# Unpack the database files; options here are "tar extract, change directory to websitesBackupsFolder, preserve permissions, verbose, file is routingXXXXXXtables.tar.gz
tar x -C ${websitesBackupsFolder} -pvf ${websitesBackupsFolder}/${importEdition}tables.tar.gz

# Remove the zip
rm -f ${websitesBackupsFolder}/${importEdition}tables.tar.gz

# Move the tables into mysql
echo $password | sudo -S mv ${websitesBackupsFolder}/${importEdition}/* /var/lib/mysql/${importEdition}

# Ensure the permissions are correct
echo $password | sudo -S chown -R mysql.mysql /var/lib/mysql/${importEdition}

# Remove the empty folder
rmdir ${websitesBackupsFolder}/${importEdition}


### Stage 6 - move the sieve into place for the purposes of having visible documentation

#	Install the sieve
mv ${websitesBackupsFolder}/sieve.sql ${websitesContentFolder}/import/


### Stage 7 - run post-install stored procedures for nearestPoint

#	Install and run the optimized nearestPoint table
mysql ${importEdition} -hlocalhost -uroot -p${mysqlRootPassword} < ${websitesContentFolder}/documentation/schema/nearestPoint.sql
mysql ${importEdition} -hlocalhost -uroot -p${mysqlRootPassword} -e "call createPathForNearestPoint();"
# Need to optimize separately (see the stored procedure for why it can't be done in there)
mysql ${importEdition} -hlocalhost -uroot -p${mysqlRootPassword} -e "optimize table map_path_for_nearestPoint;"


### Stage 8 - deal with photos-en-route

# Build the photo index
echo "#	Building the photosEnRoute tables" >> ${setupLogFile}
mysql ${importEdition} -hlocalhost -uroot -p${mysqlRootPassword} < ${websitesContentFolder}/documentation/schema/photosEnRoute.sql
mysql ${importEdition} -hlocalhost -uroot -p${mysqlRootPassword} -e "call indexPhotos(false,0);"

### Stage 9 - park the import definition file

# Rename the file by appending the edition
mv ${importMachineFile} ${importMachineFile}${importEdition}

# Finish
date
echo "All done"
echo "$(date)	Completed routing data installation ${importEdition}" >> ${setupLogFile}

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
