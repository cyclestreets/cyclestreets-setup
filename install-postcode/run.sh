#!/bin/bash
# Script to install CycleStreets Postcodes on Ubuntu
# Tested on 12.10 (View Ubuntu version using 'lsb_release -a')
# This script is idempotent - it can be safely re-run without destroying existing data
#
# Run using:
# sudo /opt/cyclestreets-setup/install-postcode/run.sh

echo "#	CycleStreets Postcode installation $(date)"

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#	This script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

### CREDENTIALS ###

# Define the location of the credentials file; see: http://stackoverflow.com/a/246128/180733
# A more advanced technique will be required if this file is called via a symlink.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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

# ONS folder
onsFolder=${websitesContentFolder}/import/ONSdata

# Switch to ONS data folder
cd ${onsFolder}

# Check the data has been downloaded
if [ ! -r ONSdata.csv ]; then

# Provide dowload instructions
    echo "#
#	STOPPING: Required data files are not present.
#
#	Official
#	--------
#	(Source tends to move around see Alternative)
#	Download the archived csv version of ONSPD data from:
#	http://www.ons.gov.uk/ons/guide-method/geography/products/postcode-directories/-nspp-/index.html
#
#	Extract the .csv from the Data folder within the archive to ${onsFolder}/ONSdata.csv
#
#	Alternative
#	-----------
#	This is an alternative source of data:
#	http://parlvid.mysociety.org/os/
#
#	The following contains dates that will obviously need updating for next time.
#
cd ${onsFolder}
wget http://parlvid.mysociety.org/os/ONSPD/2018-08.zip

# Extract this one file
unzip 2018-08.zip Data/ONSPD_AUG_2018_UK.csv
rm 2018-08.zip

# Move it
mv Data/ONSPD_AUG_2018_UK.csv ./ONSdata.csv

# Clear up (other folders Documents/ User\ Guide/ only necessary when everything was unzipped)
rm -r Data/

# Re-run this script
sudo ${ScriptHome}/install-postcode/run.sh
";
	# Terminate the script
	exit 1;
fi

# Check if the data is old. It should be updated roughly every 6 months.
daysOld=180
# The find looks for files that were modified more than ${daysOld} days ago.
if test `find "ONSdata.csv" -mtime +${daysOld}`
then

# Provide dowload instructions
    echo "#
#	STOPPING: Required data file is too old (more than ${daysOld} days}.
#	Perhaps it was left over from a previous install.
#	Remove the data, and re-run to get advice on updating:
rm ${onsFolder}/ONSdata.csv
";
	# Terminate the script
	exit 1;
fi

# External database
externalDb=csExternal

# Check the database already exists
if ! ${superMysql} --batch --skip-column-names -e "SHOW DATABASES LIKE '${externalDb}'" | grep ${externalDb} > /dev/null 2>&1
then
    echo "#	Stopping: external database ${externalDb} must exist."
    # Terminate the script
    exit 1;
fi

# Load the table definitions
${superMysql} ${externalDb} < tableDefinitions.sql


# Narrative
echo "#	Loading CSV file"

# Load the CSV file. Need to use root as website doesn't have LOAD DATA privilege.
# The --local option is needed in some situations.
mysqlimport --defaults-extra-file=${mySuperCredFile} -hlocalhost --fields-optionally-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by="\r\n" --ignore-lines=1 --local ${externalDb} ${onsFolder}/ONSdata.csv

# NB Mysql equivalent is:
## LOAD DATA INFILE '/websites/www/content/import/ONSdata/ONSdata.csv' INTO table ONSdata FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\r\n';
## SHOW WARNINGS;

# Remove the data file
rm ${onsFolder}/ONSdata.csv

# Tidy extracted data into postcode table
echo "#	Creating new postcode table"
${superMysql} ${externalDb} < newPostcodeTable.sql

# Create the partial and district postcodes
echo "#	Creating partial and district tables"
${superMysql} ${externalDb} < PartialPostcode.sql

# Confirm end of script
echo -e "#	All now installed $(date)"

# Return true to indicate success
:

# End of file
