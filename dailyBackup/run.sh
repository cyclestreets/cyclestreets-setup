#!/bin/bash
# Script to backup CycleStreets on a daily basis
# Tested on 12.10 (View Ubuntu version using 'lsb_release -a')

# This script is NOT YET idempotent - it canNOT be safely re-run without destroying existing data (the repartition will over-write)

### Stage 1 - general setup

echo "#	CycleStreets daily backup"

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#	This script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

# Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 9 || { echo 'CycleStreets daily backup is already running' ; exit 1; }

### CREDENTIALS ###

# Define the location of the credentials file; see: http://stackoverflow.com/a/246128/180733
configFile=../.config.sh
SCRIPTDIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Generate your own credentials file by copying from .config.sh.template
if [ ! -e $SCRIPTDIRECTORY/${configFile} ]; then
    echo "# The config file, ${configFile}, does not exist - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. $SCRIPTDIRECTORY/${configFile}

# Logging
# Use an absolute path for the log file to be tolerant of the changing working directory in this script
setupLogFile=$(readlink -e $(dirname $0))/log.txt
touch ${setupLogFile}
echo "#	CycleStreets daily backup in progress, follow log file with: tail -f ${setupLogFile}"
echo "#	CycleStreets daily backup $(date)" >> ${setupLogFile}

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


### Stage 2 - CycleStreets regular tasks for www

#	IJS tables
#	Do this task first so that the closure of the journey planner has a predictable time - ie. the start of the cron job.
#	Close the journey planner to stop new itineraries being made while we archive the current IJS tables
mysql cyclestreets -hlocalhost -uroot -p${mysqlRootPassword} -e "update map_config set journeyPlannerStatus='closed',whenStatusChanged=NOW(),notice='Brief closure to archive Journeys.'";
#
#	Use date time to produce an edition number for the latest routes
routesEdition=$(date +%y%m%d%H%M%S)
#
#	Archive the IJS tables
mysqldump --no-create-db --no-create-info --insert-ignore --skip-triggers -hlocalhost -uroot -p${mysqlRootPassword} cyclestreets map_itinerary map_journey map_segment map_wpt map_jny_poi map_street_hurdle map_error | gzip > ${websitesBackupsFolder}/www_routes_${routesEdition}.sql.gz

#
#	Repartition, which moves the current to the archived tables. See: documentation/schema/repartition.sql
mysql cyclestreets -hlocalhost -uroot -p${mysqlRootPassword} -e "call repartitionIJS()";
#
#	Re-open the journey planner.
mysql cyclestreets -hlocalhost -uroot -p${mysqlRootPassword} -e "update map_config set journeyPlannerStatus='live',notice=''";

#	Create md5 hash
openssl dgst -md5 ${websitesBackupsFolder}/www_routes_${routesEdition}.sql.gz > ${websitesBackupsFolder}/www_routes_${routesEdition}.sql.gz.md5

#	Backup the CycleStreets database
#	Option -R dumps stored procedures & functions
mysqldump -hlocalhost -uroot -p${mysqlRootPassword} -R cyclestreets | gzip > ${websitesBackupsFolder}/www_cyclestreets.sql.gz
#	Create md5 hash
openssl dgst -md5 ${websitesBackupsFolder}/www_cyclestreets.sql.gz > ${websitesBackupsFolder}/www_cyclestreets.sql.gz.md5

# 	Schema Structure (no data)
#	This allows the schema to be viewed at the page: http://www.cyclestreets.net/schema/sql/
#	Option -R dumps stored procedures & functions
mysqldump -R --no-data -hlocalhost -uroot -p${mysqlRootPassword} cyclestreets | gzip > ${websitesBackupsFolder}/www_schema_cyclestreets.sql.gz
#	Create md5 hash
openssl dgst -md5 ${websitesBackupsFolder}/www_schema_cyclestreets.sql.gz > ${websitesBackupsFolder}/www_schema_cyclestreets.sql.gz.md5


#	Blogs
#	These databases do not have any stored routines, so the -R option is not necessary

#	Dump
mysqldump -hlocalhost -uroot -p${mysqlRootPassword} blog | gzip > ${websitesBackupsFolder}/www_schema_blog_database.sql.gz
#	Hash
openssl dgst -md5 ${websitesBackupsFolder}/www_schema_blog_database.sql.gz > ${websitesBackupsFolder}/www_schema_blog_database.sql.gz.md5

#	Dump
mysqldump -hlocalhost -uroot -p${mysqlRootPassword} blogcyclescape | gzip > ${websitesBackupsFolder}/www_schema_blogcyclescape_database.sql.gz
#	Hash
openssl dgst -md5 ${websitesBackupsFolder}/www_schema_blogcyclescape_database.sql.gz > ${websitesBackupsFolder}/www_schema_blogcyclescape_database.sql.gz.md5

#
#	Clear out temp files which needs to be run as www-data for safety.
sudo -u www-data ${websitesContentFolder}/data/tempgenerated/zap.sh


### Final Stage

# Finish
echo "#	All done"

# Remove the lock file
) 9>/var/lock/cyclestreetsDailyBackup

# End of file
