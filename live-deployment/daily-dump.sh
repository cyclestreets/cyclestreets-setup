#!/bin/bash
# Script to dump CycleStreets data on a daily basis
# Tested on 12.10 (View Ubuntu version using 'lsb_release -a')

# This script is idempotent - it can be safely re-run without destroying existing data.

### Stage 1 - general setup

# Ensure this script is NOT run as root (it should be run as cyclestreets)
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
	flock -n 9 || { echo 'CycleStreets daily dump is already running' ; exit 1; }

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
    echo "# The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. $SCRIPTDIRECTORY/${configFile}

# Logging
setupLogFile=$SCRIPTDIRECTORY/log.txt
touch ${setupLogFile}
#echo "#	CycleStreets daily backup in progress, follow log file with: tail -f ${setupLogFile}"
echo "$(date)	CycleStreets daily backup $(id)" >> ${setupLogFile}

# Ensure there is a cyclestreets user account
if [ ! id -u ${username} >/dev/null 2>&1 ]; then
	echo "$(date) User ${username} must exist: please run the main website install script" >> ${setupLogFile}
	exit 1
fi

# Ensure the main website installation is present
if [ ! -d ${websitesContentFolder}/data/routing -o ! -d $websitesBackupsFolder ]; then
	echo "$(date) The main website installation must exist: please run the main website install script" >> ${setupLogFile}
	exit 1
fi

# Ensure this script is run as cyclestreets user
if [ ! "$(id -nu)" = "${username}" ]; then
    echo "#	This script must be run as user ${username}, rather than as $(id -nu)." 1>&2
    exit 1
fi


### Stage 2 - CycleStreets regular tasks for www

# The minimum itinerary id can be used as the handle for a batch of routes.
# Mysql options: N skips column names, s avoids the ascii-art, e introduces the query.
minItineraryId=$(mysql cyclestreets -hlocalhost -uroot -p${mysqlRootPassword} -Nse "select min(id) from map_itinerary")

# If the minItineraryId is NULL then the repartitioning can be skipped
if [ $minItineraryId = "NULL" ]; then

    #	No new routes to partition (can happen e.g if the site is in a failover mode)
    echo "$(date)	Skipping repartition" >> ${setupLogFile}

else

    #	Discard route batch files that are exactly 7 days old
    find ${websitesBackupsFolder} -name 'www_routes_*.sql.gz' -type f -mtime 7 -delete

    #	Repartition latest routes
    echo "$(date)	Repartition batch: $minItineraryId. Now closing site to routing." >> ${setupLogFile}

    #	Do this task first so that the closure of the journey planner has a predictable time - ie. the start of the cron job.
    #	Close the journey planner to stop new itineraries being made while we archive the current IJS tables
    mysql cyclestreets -hlocalhost -uroot -p${mysqlRootPassword} -e "update map_config set journeyPlannerStatus='closed',whenStatusChanged=NOW(),notice='Brief closure to archive Journeys.'";

    #	Archive the IJS tables
    dump=${websitesBackupsFolder}/www_routes_${minItineraryId}.sql.gz
    mysqldump --no-create-db --no-create-info --insert-ignore --skip-triggers -hlocalhost -uroot -p${mysqlRootPassword} cyclestreets map_itinerary map_journey map_segment map_wpt map_jny_poi map_street_hurdle map_error | gzip > ${dump}

    #	Repartition, which moves the current to the archived tables, and log the output. See: documentation/schema/repartition.sql
    mysql cyclestreets -hlocalhost -uroot -p${mysqlRootPassword} -e "call repartitionIJS()" >> ${setupLogFile}

    #	Re-open the journey planner.
    mysql cyclestreets -hlocalhost -uroot -p${mysqlRootPassword} -e "update map_config set journeyPlannerStatus='live',notice=''";

    #	Notify re-opened
    echo "$(date)	Re-opened site to routing." >> ${setupLogFile}

    #	Create md5 hash
    openssl dgst -md5 ${dump} > ${dump}.md5
fi

#	Backup the CycleStreets database
#	Option -R dumps stored procedures & functions
dump=${websitesBackupsFolder}/www_cyclestreets.sql.gz
mysqldump -hlocalhost -uroot -p${mysqlRootPassword} -R cyclestreets | gzip > ${dump}
#	Create md5 hash
openssl dgst -md5 ${dump} > ${dump}.md5

# 	Schema Structure (no data)
#	This allows the schema to be viewed at the page: http://www.cyclestreets.net/schema/sql/
#	Option -R dumps stored procedures & functions
dump=${websitesBackupsFolder}/www_schema_cyclestreets.sql.gz
mysqldump -R --no-data -hlocalhost -uroot -p${mysqlRootPassword} cyclestreets | gzip > ${dump}
#	Create md5 hash
openssl dgst -md5 ${dump} > ${dump}.md5


##	Blogs
#	The databases do not have any stored routines, so the -R option is not necessary

#	CycleStreets
#	Database dump
dump=${websitesBackupsFolder}/www_schema_blog_database.sql.gz
mysqldump -hlocalhost -uroot -p${mysqlRootPassword} blog | gzip > ${dump}
#	Hash
openssl dgst -md5 ${dump} > ${dump}.md5


#	Cyclescape
#	Database dump
dump=${websitesBackupsFolder}/www_schema_blogcyclescape_database.sql.gz
mysqldump -hlocalhost -uroot -p${mysqlRootPassword} blogcyclescape | gzip > ${dump}
#	Hash
openssl dgst -md5 ${dump} > ${dump}.md5

#	Blog code dump
dump=${websitesBackupsFolder}/www_blog_code.tgz
tar czf ${dump} -C /websites/blog content
#	Hash
openssl dgst -md5 ${dump} > ${dump}.md5

### Final Stage

# Finish
echo "$(date)	All done" >> ${setupLogFile}

# Remove the lock file - ${0##*/} extracts the scripts basename
) 9>$lockdir/${0##*/}

# End of file
