#!/bin/bash
#
#       Backup CycleStreets development system
#
#       http://dev.cyclestreets.net/wiki/BackupStrategy
#

echo "#	CycleStreets Dev machine backup $(date)"

# Ensure this script is NOT run as root
if [ "$(id -u)" = "0" ]; then
    echo "#	This script must NOT be run as root." 1>&2
    exit 1
fi

### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The second single line solution from that page is probably good enough as it is unlikely that this script itself will be symlinked.
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Use this to remove the ../
ScriptHome=$(readlink -f "${DIR}/..")

# Name of the credentials file
configFile=${ScriptHome}/.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x ${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. ${configFile}

# Bomb out if something goes wrong
set -e

#	Location of backup folder
backups=/websites/www/backups

#       Trac
dump=csTracBackup.tar.bz2

#	Park the old dump
mv ${backups}/trac ${backups}/tracOld


#	Dump
echo $password | sudo -S trac-admin /websites/dev/trac/cyclestreets hotcopy ${backups}/trac
echo $password | sudo -S chown -R cyclestreets ${backups}/trac

#	Archive
tar cjf ${backups}/${dump} -C ${backups} trac

#     Hash
openssl dgst -md5 ${backups}/${dump} > ${backups}/${dump}.md5

#	Tidyup
rm -rf ${backups}/tracOld


#	Subversion
dump=cyclestreetsRepo.dump.bz2

#      Dump
#	This takes almost half an hour in mid Feb 2012, and an hour in Jan 2013, with size 900M.
echo $password | sudo -S svnadmin dump /websites/svn/svn/cyclestreets -q | bzip2 > ${backups}/${dump}
#	Hash
openssl dgst -md5 ${backups}/${dump} > ${backups}/${dump}.md5

#	Ends
