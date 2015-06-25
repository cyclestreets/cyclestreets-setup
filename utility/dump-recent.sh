#!/bin/bash
# Description
#	Utility to dump recent CycleStreets data
# Synopsis
#	dumpPrefix should be setup by the caller and is used as a prefix for all the dump files

# The minimum itinerary id can be used as the handle for a batch of routes.
# Mysql options: N skips column names, s avoids the ascii-art, e introduces the query.
minItineraryId=$(${superMysql} cyclestreets -Nse "select min(id) from map_itinerary")

# If the minItineraryId is NULL then the repartitioning can be skipped
if [ $minItineraryId = "NULL" ]; then

    #	No new routes to partition (can happen e.g if the site is in a fallback mode)
    echo "$(date)	Skipping repartition" >> ${setupLogFile}

else
    #	Repartition latest routes
    echo "$(date)	Repartition batch: ${minItineraryId}. Now closing site to routing." >> ${setupLogFile}

    #	Do this task first so that the closure of the journey planner has a predictable time - ie. the start of the cron job.
    #	Close the journey planner to stop new itineraries being made while we archive the current IJS tables
    ${superMysql} cyclestreets -e "update map_config set journeyPlannerStatus='closed',whenStatusChanged=NOW(),notice='Brief closure to archive Journeys.'";

    #	Archive the IJS tables
    dump=${websitesBackupsFolder}/${dumpPrefix}_routes_${minItineraryId}.sql.gz
    #	Skip disable keys because renabling them takes a long time on the archive
    mysqldump --defaults-extra-file=${mySuperCredFile} -hlocalhost --no-create-db --no-create-info --insert-ignore --skip-triggers --skip-disable-keys cyclestreets map_itinerary map_journey map_street map_wpt map_jny_poi map_error | gzip > ${dump}

    #	Repartition, which moves the current to the archived tables, and log the output. See: documentation/schema/repartition.sql
    ${superMysql} cyclestreets -e "call repartitionIJS()" >> ${setupLogFile}

    #	Re-open the journey planner.
    ${superMysql} cyclestreets -e "update map_config set journeyPlannerStatus='live',notice=''";

    #	Notify re-opened
    echo "$(date)	Re-opened site to routing." >> ${setupLogFile}

    #	Create md5 hash
    openssl dgst -md5 ${dump} > ${dump}.md5
fi

#	Backup the CycleStreets database
#	Option -R dumps stored procedures & functions
dump=${websitesBackupsFolder}/${dumpPrefix}_cyclestreets.sql.gz
mysqldump --defaults-extra-file=${mySuperCredFile} -hlocalhost -R cyclestreets | gzip > ${dump}
#	Create md5 hash
openssl dgst -md5 ${dump} > ${dump}.md5

# 	Schema Structure (no data)
#	This allows the schema to be viewed at the page: http://www.cyclestreets.net/schema/sql/
#	Option -R dumps stored procedures & functions
dump=${websitesBackupsFolder}/${dumpPrefix}_schema_cyclestreets.sql.gz
mysqldump --defaults-extra-file=${mySuperCredFile} -hlocalhost -R --no-data cyclestreets | gzip > ${dump}
#	Create md5 hash
openssl dgst -md5 ${dump} > ${dump}.md5


##	Blogs
#	The databases do not have any stored routines, so the -R option is not necessary

#	CycleStreets
#	Database dump
dump=${websitesBackupsFolder}/${dumpPrefix}_schema_blogcyclestreets_database.sql.gz
mysqldump --defaults-extra-file=${mySuperCredFile} -hlocalhost blogcyclestreets | gzip > ${dump}
#	Hash
openssl dgst -md5 ${dump} > ${dump}.md5


#	Cyclescape
#	Database dump
dump=${websitesBackupsFolder}/${dumpPrefix}_schema_blogcyclescape_database.sql.gz
mysqldump --defaults-extra-file=${mySuperCredFile} -hlocalhost blogcyclescape | gzip > ${dump}
#	Hash
openssl dgst -md5 ${dump} > ${dump}.md5

# End of file
