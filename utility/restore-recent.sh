#!/bin/bash
# Description
#	Utility to restore recent CycleStreets data
# Synopsis
#	dumpPrefix should be setup by the caller and is used as a prefix for all the dump files
folder=${websitesBackupsFolder}

# Replace the cyclestreets database
echo "$(date)	Replacing CycleStreets db" >> ${setupLogFile}
${superMysql} -e "drop database if exists cyclestreets;";
${superMysql} -e "create database cyclestreets default character set utf8mb4 collate utf8mb4_unicode_ci;";
gunzip < /websites/www/backups/${dumpPrefix}_cyclestreets.sql.gz | ${superMysql} cyclestreets

#	Stop duplicated cronning from the backup machine
${superMysql} cyclestreets -e "update map_config set pseudoCron = null;";

#	Latest routes
batchRoutes="${dumpPrefix}_routes_*.sql.gz"

#	Find all route files with the named pattern that have been modified within the last 24 hours.
files=$(ssh ${server} "find ${folder}/recentroutes -maxdepth 1 -name '${batchRoutes}' -type f -mtime 0 -print")
for f in $files
do
    #	Get only the name component
    fileName=$(basename $f)

    #   Load them directly into the archive
    gunzip < ${websitesBackupsFolder}/recentroutes/$fileName | ${superMysql} csArchive
done

# Fix the ownership after the photomap rsync using the same fixups as applied by
# fallback-deployment/install-website.sh - but that requires root user.
sudo ${SCRIPTDIRECTORY}/../utility/chownPhotomapWwwdata.sh ${websitesContentFolder}


#	End of file
