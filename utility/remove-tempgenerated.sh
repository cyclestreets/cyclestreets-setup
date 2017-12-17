#!/bin/bash
# This script is part of the daily cron, which garbage collects debris left behind by the rendering of journey listings.
# It is setup by the install-website script which can be found at:
# https://github.com/cyclestreets/cyclestreets-setup

# Ensure this script is NOT run as root (it should be run as cyclestreets)
if [ "$(id -u)" = "0" ]; then
    echo "#	This script must NOT be run as root." 1>&2
    exit 1
fi


### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The multi-line method of geting the script directory is needed because this script is likely symlinked from cron
SOURCE="${BASH_SOURCE[0]}"
DIR="$( dirname "$SOURCE" )"
while [ -h "$SOURCE" ]
do 
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
  DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPTDIRECTORY=$DIR

# Define the location of the credentials file relative to script directory
configFile=../.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x $SCRIPTDIRECTORY/${configFile} ]; then
    echo "# The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. $SCRIPTDIRECTORY/${configFile}


# Main body of script

# Location of temp files
tempDir=${websitesContentFolder}/data/tempgenerated/

# This is a script to remove all the temporarily generated files.
# Note that shell wildcards should be avoided in these commands because there are too many files: use "find" instead.
#
# The following find command selects top-level files in the given paths that are older than 24 hours and deletes them.
# It works as follows:
# Folders of all the temp folders to clear out are given as paths.
# -maxdepth option stops find going into the .svn folders relative to the paths.
# ! (which is escaped) negates the next test.
# -mtime 0 finds files modified within the last 24 hours
# -type f finds only files
# ! -name Skips files matching the given name
folders="elevationProfile maplet photomaplet"
for folder in ${folders}
do
    find ${tempDir}${folder} -maxdepth 1 \! -mtime 0 \! -name '.gitignore' -type f -delete
done

# Thumbnails
# It is not usually necessary to clear out the thumbnails, but rather than using a clever find it is simpler to:
# 1. Delete the thumbnail folders and contents
#	rm -rf thumbnails
#	rm -rf thumbnails2
# 2. Re-create the thumbnails folder, best done by svn update from the tempgenerated folder:
#	cyclestreets@www:${websitesContentFolder}/data/tempgenerated$ svn update
# 3. You may need to update ownership
#    cyclestreets@www:${websitesContentFolder}/data/tempgenerated$ sudo chown -R www-data thumbnails
#    cyclestreets@www:${websitesContentFolder}/data/tempgenerated$ sudo chown -R www-data thumbnails2


# End of file
