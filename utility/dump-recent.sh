#!/bin/bash
# Description
#	Utility to dump recent CycleStreets data
#	It moves all the data in the itinerary, journey, waypoint, error tables to their archive equivalents in the csArchive database.
#	The reason for doing this is that it keeps these tables small and hence quick to insert new data as the indexes remain small.
# Synopsis
#	dumpPrefix (string)
#	Eg. "www" is used to indicate which server created the dump. Used as a prefix for all the dump file names.

# The minimum itinerary id can be used as the handle for a batch of routes.
# Mysql options: N skips column names, s avoids the ascii-art, e introduces the query.
minItineraryId=$(${superMysql} cyclestreets -Nse "select min(id) from map_itinerary")

# Check the minItineraryId
if [ "${minItineraryId}" = "NULL" ]; then

    #	No new routes to partition (can happen e.g if the site is in a fallback mode)
    echo "$(date)	No new routes, so skipping repartition." >> ${setupLogFile}

else
    #	Repartition latest routes
    echo "$(date)	Repartition batch: ${minItineraryId}. Now closing site to routing." >> ${setupLogFile}

    #	Do this task first so that the closure of the journey planner has a predictable time - ie. the start of the cron job.
    #	Close the journey planner to stop new itineraries being made while we archive the current IJS tables
    ${superMysql} cyclestreets -e "update map_config set journeyPlannerStatus='closed',whenStatusChanged=NOW(),notice='Brief closure to archive Journeys.'";

    # The minimum error id - which needs to be captured before repartitioning
    minErrorId=$(${superMysql} cyclestreets -Nse "select min(id) from map_error")
    
    #	Repartition, which moves the current to the archived tables, and log the output. See: documentation/schema/repartition.sql
    ${superMysql} cyclestreets -e "call repartitionIJS()" >> ${setupLogFile}

    #	Re-open the journey planner
    ${superMysql} cyclestreets -e "update map_config set journeyPlannerStatus='live',notice=''";

    #	Notify re-opened
    echo "$(date)	Re-opened site to routing." >> ${setupLogFile}

    #	Archive the IJS tables
    dump=${websitesBackupsFolder}/recentroutes/${dumpPrefix}_routes_${minItineraryId}.sql.gz
    
    #	Skip disable keys because re-enabling them takes a long time on the archive
    dumpOptions="--defaults-extra-file=${mySuperCredFile} -hlocalhost --no-create-db --no-create-info --insert-ignore --skip-triggers --skip-disable-keys --hex-blob"

    # Dump itinerary
    mysqldump ${dumpOptions} csArchive map_itinerary_archive --where="id>=${minItineraryId}" | gzip > ${dump}

    # Append the other tables (different where)
    mysqldump ${dumpOptions} csArchive map_waypoint_archive map_street_archive map_jny_poi_archive --where="itineraryId>=${minItineraryId}" | gzip >> ${dump}

    # Append the journey archive table avoiding rows with invalid geometry
    mysqldump ${dumpOptions} csArchive map_journey_archive --where="itineraryId>=${minItineraryId} and st_isvalid(routePoints) = 1" | gzip >> ${dump}

    # Append the error table
    if [ "${minErrorId}" != "NULL" ]; then
	mysqldump ${dumpOptions} csArchive map_error_archive --where="id>=${minErrorId}" | gzip >> ${dump}
    fi

    #	Notify dumped
    echo "$(date)	Dump file created." >> ${setupLogFile}

    #	Create md5 hash
    openssl dgst -md5 ${dump} > ${dump}.md5
fi

#	Backup the CycleStreets database
#	Option -R dumps stored procedures & functions
dump=${websitesBackupsFolder}/${dumpPrefix}_cyclestreets.sql.gz
mysqldump --defaults-extra-file=${mySuperCredFile} --hex-blob -hlocalhost -R cyclestreets | gzip > ${dump}
#	Create md5 hash
openssl dgst -md5 ${dump} > ${dump}.md5

# 	Schema Structure (no data)
#	This allows the schema to be viewed at the page: http://www.cyclestreets.net/schema/sql/
#	Option -R dumps stored procedures & functions
dump=${websitesBackupsFolder}/${dumpPrefix}_schema_cyclestreets.sql.gz
mysqldump --defaults-extra-file=${mySuperCredFile} --hex-blob -hlocalhost -R --no-data cyclestreets | gzip > ${dump}
#	Create md5 hash
openssl dgst -md5 ${dump} > ${dump}.md5


##	Blogs
#	The databases do not have any stored routines, so the -R option is not necessary

#	Blog CycleStreets
#	Database dump
dump=${websitesBackupsFolder}/${dumpPrefix}_schema_blogcyclestreets_database.sql.gz
mysqldump --defaults-extra-file=${mySuperCredFile} --hex-blob -hlocalhost blogcyclestreets | gzip > ${dump}
#	Hash
openssl dgst -md5 ${dump} > ${dump}.md5


##	Batch routing db
#	Only three key tables which contain client data need backing up
dump=${websitesBackupsFolder}/${dumpPrefix}_csBatch_jobs_servers_threads.sql.gz
mysqldump --defaults-extra-file=${mySuperCredFile} --hex-blob -hlocalhost csBatch map_batch_jobs map_batch_servers map_batch_threads | gzip > ${dump}
#	Hash
openssl dgst -md5 ${dump} > ${dump}.md5


# End of file
