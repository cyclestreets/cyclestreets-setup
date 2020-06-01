#!/bin/bash
# Description
#	Utility to restore recent CycleStreets data
# Synopsis
#	dumpPrefix should be setup by the caller and is used as a prefix for all the dump files
folder=${websitesBackupsFolder}

# Fix the ownership after the photomap rsync using the same fixups as applied by
# fallback-deployment/install-website.sh - but that requires root user.
echo "$(date)	Photomap ownership" >> ${setupLogFile}
sudo ${SCRIPTDIRECTORY}/../utility/chownPhotomapWwwdata.sh ${websitesContentFolder}

# Replace the cyclestreets database
echo "$(date)	Replacing CycleStreets db" >> ${setupLogFile}
# Close the site during this time
touch ${websitesContentFolder}/maintenance
${superMysql} -e "drop database if exists cyclestreets;";
${superMysql} -e "create database cyclestreets default character set utf8mb4 collate utf8mb4_unicode_ci;";
gunzip < /websites/www/backups/${dumpPrefix}_cyclestreets.sql.gz | ${superMysql} cyclestreets

# Re-open the site after the cyclestreets db has been restored
rm ${websitesContentFolder}/maintenance

#	Stop duplicated cronning from the backup machine
${superMysql} cyclestreets -e "update map_config set pseudoCron = null;";


#	Recent routes
if [ "$restoreRecentRoutes" = true ]; then

    recentRoutes="${dumpPrefix}_routes_*.sql.gz"

    #	Find all route files with the named pattern that have been modified within the last 24 hours.
    files=$(ssh ${server} "find ${folder}/recentroutes -maxdepth 1 -name '${recentRoutes}' -type f -mtime 0 -print")
    for f in $files
    do
	#	Get only the name component
	fileName=$(basename $f)

	#   Load them directly into the archive
	gunzip < ${websitesBackupsFolder}/recentroutes/$fileName | ${superMysql} csArchive
	echo "$(date)	Restored to archive: $fileName" >> ${setupLogFile}
    done
fi
#	End of file
