#!/bin/bash
# Script to install CycleStreets Postcodes.
usage()
{
    cat << EOF

SYNOPSIS
	$0 -h

OPTIONS
	-h Show this message

DESCRIPTION
	Downloads and installs or updates the table of Uk postcodes.

GET DATA

Official
--------
(Source tends to move around see Alternative)
Download the archived csv version of ONSPD data from:
https://geoportal.statistics.gov.uk/datasets/ons-postcode-directory-november-2023

On 11 Oct 2024 the most recent is Aug 2024 found via this search:
https://geoportal.statistics.gov.uk/search?collection=Dataset&sort=-created&tags=all(PRD_ONSPD%2CAUG_2024)
231MB download. The .csv is 1.4GB.

Extract the .csv from the Data folder within the archive to ${onsFolder}/ONSdata.csv

Alternative
-----------
This is an alternative source of data, but latest is Nov-2022:
http://parlvid.mysociety.org/os/

EOF
}

# http://wiki.bash-hackers.org/howto/getopts_tutorial
# An opening colon in the option-string switches to silent error reporting mode.
# Colons after letters indicate that those options take an argument e.g. m takes an email address.
while getopts "h" option ; do
    case ${option} in
        h) usage; exit ;;
	# Missing expected argument
	:)
	    echo "Option -$OPTARG requires an argument." >&2
	    exit 1
	    ;;
	\?) echo "Invalid option: -$OPTARG" >&2 ; exit ;;
    esac
done

# After getopts is done, shift all processed options away with
shift $((OPTIND-1))


echo "#	CycleStreets Postcode installation $(date)"

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#	This script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e


### DEFAULTS ###

# External database (leave empty if not wanted)
externalDb=


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
    echo "#	The config file, ${configFile}, does not exist or is not executable - copy your own based on the ${configFile}.template file." 1>&2
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
#	STOPPING: Required data files are not present. See help.

The following contains dates that will obviously need updating for next time.

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

# Check external database
if [ -z "${externalDb}" ]; then

    echo "#	STOPPING: The required external db is not configured to be setup on this server.";

    # Terminate the script
    exit 1;
fi


# Useful binding
# The defaults-extra-file is a positional argument which must come first.
superMysql="mysql --defaults-extra-file=${mySuperCredFile} -hlocalhost"

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
# May also need:
# set global local_infile=true;
mysqlimport --defaults-extra-file=${mySuperCredFile} -hlocalhost --fields-optionally-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by="\r\n" --ignore-lines=1 --local ${externalDb} ${onsFolder}/ONSdata.csv

# NB Mysql equivalent is:
## LOAD DATA INFILE '/websites/www/content/import/ONSdata/ONSdata.csv' INTO table csExternal.ONSdata FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES;
## SHOW WARNINGS;

# Remove the data file
rm ${onsFolder}/ONSdata.csv

# Tidy extracted data into postcode table
echo "#	Creating new postcode table"
${superMysql} ${externalDb} < newPostcodeTable.sql

# Create the partial and district postcodes
echo "#	Creating partial and district tables"
${superMysql} ${externalDb} < PartialPostcode.sql

# Label with installed date
installedDate=$(date +%F)
${superMysql} ${externalDb} -e "alter table map_postcode comment = 'UK postcodes from Office of National Statistics, installed ${installedDate}'"


# Confirm end of script
echo -e "#	All now installed $(date)"

# Return true to indicate success
:

# End of file
