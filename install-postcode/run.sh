#!/bin/bash
# Script to install CycleStreets Postcodes.
# Does NOT need to be run as root
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
This searches for: ons postcode directory
https://geoportal.statistics.gov.uk/search?q=ons%20postcode%20directory&sort=Date%20Created%7Ccreated%7Cdesc
For Aug 2025 the .csv was 1.19GB. Save it to /import/ONSdata/ONSdata.csv

Alternative
-----------
This is an alternative source of data, latest is Aug-2025:
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
wget http://parlvid.mysociety.org/os/ONSPD/2025-08.zip

# Extract this one file
unzip 2025-08.zip Data/ONSPD_AUG_2025_UK.csv
rm 2025-08.zip

# Move it
mv Data/ONSPD_AUG_2025_UK.csv ./ONSdata.csv

# Clear up (other folders Documents/ User\ Guide/ only necessary when everything was unzipped)
rm -r Data/

# Re-run this script
${ScriptHome}/install-postcode/run.sh
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
echo "#	Loading the table definitions"
${superMysql} ${externalDb} < tableDefinitions.sql

# Handle secure-file-priv, if set
# Use of set from comment by dorsh:
# https://stackoverflow.com/a/9558954/225876
# This puts the values of the two columns in $1 and $2
set $(${superMysql} --batch --skip-column-names --silent -e "show variables like 'secure_file_priv'")
secureFilePriv=$2

# If there's a secure folder then move the csv file there
if [ -n "$secureFilePriv" ]; then

	# Secure readable location
	mysqlReadableFolder=${secureFilePriv}

	# Ensure it exists
	mkdir -p ${mysqlReadableFolder}

	# Move csv file there
	mv ${onsFolder}/ONSdata.csv ${mysqlReadableFolder}

	# Set path
	ONSdataFile=${mysqlReadableFolder}/ONSdata.csv

else
	# Set path
	ONSdataFile=${onsFolder}/ONSdata.csv
fi

# Narrative
echo "#	Loading CSV file"

# Load the CSV file. Need to use root as website doesn't have LOAD DATA privilege.
# -ignore is needed as the Aug 2025 contained duplicates for e.g KY7 5TA
mysqlimport --defaults-extra-file=${mySuperCredFile} -hlocalhost --fields-optionally-enclosed-by='"' --fields-terminated-by=',' --lines-terminated-by="\n" --ignore-lines=1 --ignore  ${externalDb} ${ONSdataFile}

# NB Mysql equivalent is:
## load data infile '/websites/www/content/import/ONSdata/ONSdata.csv' ignore into table csExternal.ONSdata fields terminated by ',' optionally enclosed by '"' lines terminated by '\n' ignore 1 lines;
## SHOW WARNINGS;

# Remove the data file
rm -f ${ONSdataFile}

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
