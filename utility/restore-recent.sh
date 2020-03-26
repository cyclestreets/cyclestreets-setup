#!/bin/bash
# Description
#	Utility to restore recent CycleStreets data
# Synopsis
#	dumpPrefix should be setup by the caller and is used as a prefix for all the dump files

folder=${websitesBackupsFolder}
download=${SCRIPTDIRECTORY}/../utility/downloadDumpAndMd5.sh

#	Download CyclesStreets Schema
$download $administratorEmail $server $folder ${dumpPrefix}_schema_cyclestreets.sql.gz

#	Download & Restore CycleStreets database
$download $administratorEmail $server $folder ${dumpPrefix}_cyclestreets.sql.gz

# Replace the cyclestreets database
echo "$(date)	Replacing CycleStreets db" >> ${setupLogFile}
${superMysql} -e "drop database if exists cyclestreets;";
${superMysql} -e "create database cyclestreets default character set utf8mb4 collate utf8mb4_unicode_ci;";
gunzip < /websites/www/backups/${dumpPrefix}_cyclestreets.sql.gz | ${superMysql} cyclestreets

#	Stop duplicated cronning from the backup machine
${superMysql} cyclestreets -e "update map_config set pseudoCron = null;";

#	Sync the photomap
# Use option -O (omit directories from --times), necessary because apparently only owner (or root) can set a directory's mtime.
# rsync can produce other errors such as:
# rsync: mkstemp "/websites/www/content/data/photomap2/46302/.original.jpg.H3xy2f" failed: Permission denied (13)
# rsync: mkstemp "/websites/www/content/data/photomap2/46302/.rotated.jpg.Y3sb28" failed: Permission denied (13)
# these appear to be temporary files, possibly generated and owned by the system. Hard to track down and probably safe to ignore.
# Tolerate errors from rsync
set +e
rsync -rtO --cvs-exclude ${server}:${websitesContentFolder}/data/photomap ${websitesContentFolder}/data
rsync -rtO --cvs-exclude ${server}:${websitesContentFolder}/data/photomap2 ${websitesContentFolder}/data
rsync -rtO --cvs-exclude ${server}:${websitesContentFolder}/data/photomap3 ${websitesContentFolder}/data

# Hosted
rsync -a --cvs-exclude ${server}:${websitesContentFolder}/hosted ${websitesContentFolder}/

# Fix the ownership after the rsync above using the same fixups as applied by fallback-deployment/install-website.sh - but that requires root user.
sudo ${SCRIPTDIRECTORY}/../utility/chownPhotomapWwwdata.sh ${websitesContentFolder}

#	Also sync the blog code
# Note: WordPress checks that files are owned by the webserver user (rather than just checking they are writable) so these fixes may be necessary
# chown -R www-data:${rollout} /websites/blog/content/
# chmod -R g+w /websites/blog/content/
# !! Hardwired locations
# Include the l option to copy symlinks as symlinks
rsync -rtOl --cvs-exclude ${server}:/websites/blog/content /websites/blog

# Resume exit on error
set -e

#	Latest routes
batchRoutes="${dumpPrefix}_routes_*.sql.gz"

#	Find all route files with the named pattern that have been modified within the last 24 hours.
files=$(ssh ${server} "find ${folder}/recentroutes -maxdepth 1 -name '${batchRoutes}' -type f -mtime 0 -print")
for f in $files
do
    #	Get only the name component
    fileName=$(basename $f)

    #	Get the latest copy of www's current IJS tables.
    $download $administratorEmail $server ${folder}/recentroutes $fileName

    #   Load them directly into the archive
    gunzip < ${websitesBackupsFolder}/recentroutes/$fileName | ${superMysql} csArchive
done

#	CycleStreets Blog
$download $administratorEmail $server $folder ${dumpPrefix}_schema_blogcyclestreets_database.sql.gz
${superMysql} cyclestreets -e "drop database if exists blogcyclestreets;";
${superMysql} cyclestreets -e "create database blogcyclestreets default character set utf8mb4 collate utf8mb4_unicode_ci;";
gunzip < /websites/www/backups/${dumpPrefix}_schema_blogcyclestreets_database.sql.gz | ${superMysql} blogcyclestreets

#	End of file
