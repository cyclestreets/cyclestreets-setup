#!/bin/bash
# Description
#	Utility to sync recent CycleStreets data
# Synopsis
#	dumpPrefix should be setup by the caller and is used as a prefix for all the dump files

folder=${websitesBackupsFolder}
download=${SCRIPTDIRECTORY}/../utility/downloadDumpAndMd5.sh

#	Download CyclesStreets Schema (no data)
$download $administratorEmail $server $folder ${dumpPrefix}_schema_cyclestreets.sql.gz

#	Download CycleStreets database
$download $administratorEmail $server $folder ${dumpPrefix}_cyclestreets.sql.gz

#	Download Batch database key tables
$download $administratorEmail $server $folder ${dumpPrefix}_csBatch_jobs_servers_threads.sql.gz


#	Sync the photomap
# Use option -O (omit directories from --times), necessary because apparently only owner (or root) can set a directory's mtime.
# rsync can produce other errors such as:
# rsync: mkstemp "/websites/www/content/data/photomap2/46302/.original.jpg.H3xy2f" failed: Permission denied (13)
# rsync: mkstemp "/websites/www/content/data/photomap2/46302/.rotated.jpg.Y3sb28" failed: Permission denied (13)
# these appear to be temporary files, possibly generated and owned by the system. Hard to track down and probably safe to ignore.
# To avoid them use:
# sudo chmod g+w -R ${websitesContentFolder}/data/photomap*

if [ "$restorePhotomap" = true ]; then

    # Tolerate errors from rsync
    set +e
    rsync -rtO --cvs-exclude ${server}:${websitesContentFolder}/data/photomap ${websitesContentFolder}/data
    rsync -rtO --cvs-exclude ${server}:${websitesContentFolder}/data/photomap2 ${websitesContentFolder}/data
    rsync -rtO --cvs-exclude ${server}:${websitesContentFolder}/data/photomap3 ${websitesContentFolder}/data
    # Resume exit on error
    set -e
fi

# Tolerate errors from rsync
set +e

# Sync the migration status
rsync -rtO --cvs-exclude ${server}:${websitesContentFolder}/data/dbmigrate.txt ${websitesContentFolder}/data

# Hosted
rsync -a --cvs-exclude ${server}:${websitesContentFolder}/hosted ${websitesContentFolder}/

# Resume exit on error
set -e

#	Journey Planner recent routes
if [ "$restoreRecentRoutes" = true ]; then
   rsync -a ${server}:${folder}/recentroutes ${folder}
fi

#	End of file
