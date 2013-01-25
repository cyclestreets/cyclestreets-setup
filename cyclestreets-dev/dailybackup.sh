#!/bin/bash
#
#       Backup CycleStreets development system
#
#       http://dev.cyclestreets.net/wiki/BackupStrategy
#
#	Install on the dev machine with:
#	ln -s /websites/www/content/configuration/backup/dev/cyclestreetsDev /etc/cron.daily/cyclestreetsDev
#	This file is called by the cron.daily system as root user.

#	Location of backup folder
backups=/websites/www/backups

#	File maniuplation is done as user simon (rather than root) for safety.
#	That user is set up to have access to the repo and trac for backup purposes.
asSimon="sudo -u simon"


#	Subversion
dump=cyclestreetsRepo.dump.bz2

#      Dump
#	This takes almost half an hour in mid Feb 2012, and an hour in Jan 2013, with size 900M.
${asSimon} svnadmin dump /websites/svn/svn/cyclestreets | bzip2 > ${backups}/${dump}
#	Hash
${asSimon} openssl dgst -md5 ${backups}/${dump} > ${backups}/${dump}.md5

#	Retain ownership of these files
chown simon:simon ${backups}/${dump}
chown simon:simon ${backups}/${dump}.md5

#       Trac
dump=csTracBackup.tar.bz2

#	Dump
${asSimon} mv ${backups}/trac ${backups}/tracOld
${asSimon} trac-admin /websites/dev/trac/cyclestreets hotcopy ${backups}/trac
${asSimon} tar cjf ${backups}/${dump} -C ${backups} trac
#     Hash
${asSimon} openssl dgst -md5 ${backups}/${dump} > ${backups}/${dump}.md5

#	Retain ownership of these files
chown simon:simon ${backups}/${dump}
chown simon:simon ${backups}/${dump}.md5

#	Tidyup
${asSimon} rm -rf ${backups}/tracOld

#	Ends
