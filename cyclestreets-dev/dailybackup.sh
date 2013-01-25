#!/bin/bash
#
#       Backup CycleStreets development system
#
#       http://dev.cyclestreets.net/wiki/BackupStrategy
#

#	Location of backup folder
backups=/websites/www/backups


#	Subversion
dump=cyclestreetsRepo.dump.bz2

#      Dump
#	This takes almost half an hour in mid Feb 2012, and an hour in Jan 2013, with size 900M.
svnadmin dump /websites/svn/svn/cyclestreets | bzip2 > ${backups}/${dump}
#	Hash
openssl dgst -md5 ${backups}/${dump} > ${backups}/${dump}.md5

#       Trac
dump=csTracBackup.tar.bz2

#	Dump
mv ${backups}/trac ${backups}/tracOld
trac-admin /websites/dev/trac/cyclestreets hotcopy ${backups}/trac
tar cjf ${backups}/${dump} -C ${backups} trac
#     Hash
openssl dgst -md5 ${backups}/${dump} > ${backups}/${dump}.md5

#	Tidyup
rm -rf ${backups}/tracOld

#	Ends
