#!/bin/bash
#
#	A helper script that downloads a dump file (and it's .md5 check) from a folder on a server.
#	A key feature of this script is that it will wait (for up to: minutesWait minutes) for the dump file to become available.
#
#	SYNOPSIS
#	downlodaDumpAndMd5.sh email server folder name
#
#	DESCRIPTION
#	The arguments are:
#	email used to notify of any problems
#	server e.g. www.cyclescape.org
#	folder relative to root (not slash terminated) e.g. /websites/cyclescape/backup
#	name of the archive file e.g. cyclescapeShared.tar.bz2

# Ensure this script is NOT run as root (it should be run as cyclestreets)
if [ "$(id -u)" = "0" ]; then
    echo "#	This script must NOT be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

#	Folder locations
email=$1
server=$2
folder=$3
archive=$4
dump=${folder}/${archive}
md5=${dump}.md5

#	Log
log=${folder}/log.txt
# 	In addition to making sure the log exists this updates the modified time
touch $log

#	Notify
subject="CycleStreets cron scripts: A dump download issue on server: $server has arisen $0"

#	A function to log and email its first argument, which should be a helpful message
function logAndEmail {
    echo "$(date --iso-8601=seconds)	$1" >> $log
    echo $1 | mail -s "$subject" "$email"
}

# The dump file may be in the process of being generated when this script is called.
# So we should wait for up to this many minutes until the md5 file is ready before starting the download.
minutesWait=10

#	Use this to determine whether to download.
download=0
#	Use this to help debug why a download has not worked.
reason="OK"

#	Full day ago, used to ensure downloads are at least as fresh as this date.
fullDayAgo=$(($(date +%s) - 24 * 3600))

#	The size of the current dump - if it exists
size=0
size80=0
if [ -r $dump ]
then
    size=$(stat -c%s $dump)
    # 80% of the size
    size80=$((($size - ($size/5))))

    # Log
    echo "$(date --iso-8601=seconds)	Size of existing ${dump} is ${size}" >> $log
fi

#	Keep trying while there's still time
while [ $minutesWait -gt 0 ]
do
    # Reduce the minutesWait counter
    minutesWait=$(( $minutesWait - 1 ))

    # Debug message
    reason="Not OK at ${minutesWait}"

    # The test checks that:
    # 1. The md5 exists (readable)
    # 2. The dump is readable and is fresh
    # 3. The md5's size > 0
    # 4. The md5's modification time was fresh enough
    # 5. The md5 is 'not older than' the dump (it can be created in the same second)

    # The test is split into two parts as the $(date...) test fails and messes up if the $md5 does not exist.

    # Check first part
    ssh ${server} "test -r ${md5} -a -r ${dump} -a \$(date -r ${dump} +%s) -ge ${fullDayAgo}"

    # If the test succeeds, then check the second part
    if [ $? = 0 ]
    then

	# Debug
	reason="md5 and dump are readable at ${minutesWait}"

	# Check second part
	ssh ${server} "test \$(stat -c%s ${md5}) -gt 0 -a \$(date -r ${md5} +%s) -ge ${fullDayAgo} -a ! ${md5} -ot ${dump}"

    	# If the test succeeds, then start downloading, else wait.
	if [ $? = 0 ]
	then

		# Jump out of the loop to start downloading
		download=1
		break
	fi
    fi

    # Trace
    # echo "$(date --iso-8601=seconds)	The md5 is not ready, waiting minutes left = ${minutesWait}"

    # Wait a minute
    sleep 60
done

#	Abandon if a new enough md5 was not found
if [ ! $download = 1 ]
then
    # Notifiy problem
    logAndEmail "Abandoning the download of ${dump}, ${reason}."
    exit 1
fi

#	Download the md5, preserving timing data
#	The -p tries to set the mode of the file, which will require the right permissions
scp -p ${server}:${md5} ${folder}
#	Log
echo "$(date --iso-8601=seconds)	Fetched ${md5}" >> $log


#	Download the main file
# scp -p ${server}:${dump} ${folder}
#	Use rsync instead...
rsync -t ${server}:${dump} ${folder}
#	Log
echo "$(date --iso-8601=seconds)	Fetched ${dump}" >> $log

#	The dump must be readable
if [ ! -r ${dump} ]
then
    logAndEmail "Dump: ${dump} does not exist or is not readable, stopping."
    exit 1
fi

#	The md5 must be readable
if [ ! -r ${md5} ]
then
    logAndEmail "MD5 checksum: ${md5} does not exist or is not readable, stopping."
    exit 1
fi

#	Check the md5 matches
if [ "$(openssl dgst -md5 ${dump})" != "$(cat ${md5})" ]
then
    logAndEmail "The md5 checksum for dump: ${dump} does not match, stopping."
    exit 1
fi

#	Warn if the dump has shrunk
newSize=$(stat -c%s $dump)
#	Log
echo "$(date --iso-8601=seconds)	Size of new ${dump} is ${newSize}" >> $log
if [ $newSize -lt $size80 ]
then
    logAndEmail "${dump} has shrunk by more than 20% from ${size} to ${newSize}"
fi

# Successful completion: return true
:

# End of file
