#!/bin/bash
# Script to install CycleStreets Postcodes.
# Does NOT need to be run as root

# Data location
dataFilename=ONSdata.csv
onsFolderRelative=import/ONSdata

usage()
{
    cat << EOF

SYNOPSIS
	$0 -h

OPTIONS
	-h Show this message

DESCRIPTION
	Installs or updates the table of UK postcodes from a manually obtained download, see below.
	The upstream data format changes often.
	This version of the script works with only a minimal set of fields, and so should be more resilient to changes than earlier versions.

GET DATA

National Statistics Postcode Database (NSPD) Open
-------------------------------------------------
This searches for: ONSPD Online latest Postcode Centroids
https://geoportal.statistics.gov.uk/search?q=ONSPD%20Online%20latest%20Postcode%20Centroids&sort=Date%20Created%7Ccreated%7Cdesc
Save it to: ${onsFolderRelative}/${dataFilename}

The size of the .csv file in September 2026 was 1.3GB, in August 2025 it was 1.19GB.

Older versions up to Aug 2025 are available at: http://parlvid.mysociety.org/os/

November 2026
-------------
Data for September 2026 data was obtained, but the latest user guide was for August 2026:
ONS Postcode Directory (August 2026) User Guide
https://geoportal.statistics.gov.uk/datasets/920df475305b4b6baa9c3cab10813ca7/about

The fields are described in the Annex of the User guide, in a table labelled: ONSPD Record Specification.

These are the essential fields for the purposes of this script:

| Field  | Length | Range           | Data description    | Brief comment                                                            |
|--------+--------+-----------------+---------------------+--------------------------------------------------------------------------|
| PCD7   |      7 | AB1_0AA-ZE999ZZ | Postcode – 7 chars  | Live postcodes UK, Channel Islands, Isle of Man, monthly from Royal Mail |
| DOTERM |      6 | YYYYMM or null  | Date of termination | Null for live postcodes - a useful filter                                |
| EAST1M |      6 | numeric or null | Easting             | Null for non-geographic postcodes - a useful filter                      |
| LAT    |     10 | numeric         | latitude            | Latitude  to six decimal places; 99.999999 for CI and IoM                |
| LONG   |     10 | numeric         | longitude           | Longitude to six decimal places;  0.000000 for CI and IoM                |

This list of fields is used as the 'selectFields' in the script below.
It is all that is needed to extract and build a postcode lookup table in MySQL.

EOF
}

## Parse the script options
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
    echo "#	STOPPING: The config file, ${configFile}, does not exist or is not executable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. ${configFile}


## Main body of sctipt

# ONS folder
onsFolder=${websitesContentFolder}/${onsFolderRelative}

# Switch to ONS data folder
cd ${onsFolder}

# Check the data has been downloaded
if [ ! -r ${dataFilename} ]; then
	# Abandon
    echo "#	STOPPING: The data file: ${dataFilename} is not found. Get help using the option -h.";
	exit 1;
fi

# Check if the data is old. It should be updated roughly every 6 months.
daysOld=180
# The find looks for files that were modified more than ${daysOld} days ago.
if test `find "${dataFilename}" -mtime +${daysOld}`
then

# Provide dowload instructions
    echo "#
#	STOPPING: Required data file is too old (more than ${daysOld} days}.
#	Perhaps it was left over from a previous install.
#	Remove the data, and re-run to get advice on updating:
rm ${onsFolder}/${dataFilename}
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
superMysql="mysql --defaults-extra-file=${mySuperCredFile} --host=localhost"

# Check the database already exists
if ! ${superMysql} --batch --skip-column-names -e "SHOW DATABASES LIKE '${externalDb}'" | grep ${externalDb} > /dev/null 2>&1
then
    echo "#	STOPPING: The external database ${externalDb} must exist."
    # Terminate the script
    exit 1;
fi

# Load the table definitions
#echo "#	Loading the table definitions"
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
	mv ${onsFolder}/${dataFilename} ${mysqlReadableFolder}

	# Set path
	ONSdataFile=${mysqlReadableFolder}/${dataFilename}

else
	# Set path
	ONSdataFile=${onsFolder}/${dataFilename}
fi
dataLines=$(wc -l < ${ONSdataFile})
echo -e "#	The data file has: ${dataLines} lines."

## Identify required columns
#
# Extract the essential data into a table mapping postcode to coordinate
# This is an outline of the procedure
#
# 1. The ONS data file CSV contains over 50 columns, and over 2 million rows.
# 2, Only a handful of columns are needed - these are the select fields.
# 3. The safe fields are a copy of the select fields, with some translations
#    to avoid MySQL reserved words and for readability.
# 4. The first line of the CSV file provides a list of headings.
# 5. From the list of headings the number of each select field can be determined.
# 6. Use the select field numbers to extract a temporary smaller CSV file.
# 7. The order of fields in the temporary file stays the same as in the original.
# 8. A MySQL table is defined based on the safe fields, respecting the ordering.
# 9. The table is filled from the temporary file.



# Select fields
# This is the minimum set of fields / columns from the source file that are required for this script.
selectFieldsCsv=PCD7,LAT,LONG,DOTERM,EAST1M

# Safe fields
# Copy
safeFieldsCsv=${selectFieldsCsv}
# Translations
# Because LONG is a reserved word in MySQL rewrite it
safeFieldsCsv=${safeFieldsCsv/LONG/lon}
# Other translations for readability
safeFieldsCsv=${safeFieldsCsv/LAT/lat}

# Create list versions of the above using arrays
declare -a selectFieldsList=()
declare -a safeFieldsList=()
# Explode CSV
# https://stackoverflow.com/a/60756921/225876
IFS=, read -ra selectFieldsList <<< "${selectFieldsCsv}"
unset IFS
IFS=, read -ra safeFieldsList <<< "${safeFieldsCsv}"
unset IFS
# Tidy: no longer needed
unset selectFieldsCsv
unset safeFieldsCsv

## Create a mapping from a select field to a safe field
# Declare an associative array
declare -A select2safe
# Use exclamation point to access array indices
for i in "${!selectFieldsList[@]}"; do
	selectField=${selectFieldsList[$i]}
	safeField=${safeFieldsList[$i]}
	select2safe[$selectField]=$safeField
done
# Tidy: no longer needed
unset safeFieldsList


# Headings from the data file
headingsCsv=$(head -n1 ${ONSdataFile})
# Explode CSV
declare -a headingsList=()
IFS=, read -ra headingsList <<< "${headingsCsv}"
unset IFS

# Declare arrays to record the field number and sort order
# of the select fields in the headings list.
declare -a selectFieldsSortedList
declare -a selectFieldsNumberList

# Scan the headings in order, looking for selectFields
# Exclamation point works through the zero-based index of the array
for i in ${!headingsList[@]}; do

	# Bind the heading
	heading=${headingsList[$i]}

	# Test if this heading is among the select fields
	for element in "${selectFieldsList[@]}"; do
		if [[ "$heading" == "$element" ]]; then

			# Collate
			selectFieldsSortedList+=($heading)

			# Add one for 1-based field numbers
			selectFieldsNumberList+=($(($i + 1)))
			break
		fi
	done
done
# Tidy: no longer needed
unset selectFieldsList
#echo -e "#	selectFieldsSortedList"
#printf "%s\n"  "${selectFieldsSortedList[@]}"
#echo -e "#	selectFieldsNumberList"
#printf "%s\n"  "${selectFieldsNumberList[@]}"

# Implode
selectFieldNumbersSortedCsv=$(IFS=, ; echo "${selectFieldsNumberList[*]}")
# Tidy: no longer needed
unset selectFieldsNumberList

## Create a table definition using the safe fields
# A list of columns
declare -a columnDefinitionsList=()
for fieldName in "${selectFieldsSortedList[@]}"; do
	safeName=${select2safe[$fieldName]}
	columnDefinitionsList+=("${safeName} VARCHAR(10) NULL")
done
#echo -e "#	columnDefinitionsList"
#printf "%s\n"  "${columnDefinitionsList[@]}"

# Implode
columnDefinitionsCsv=$(IFS=, ; echo "${columnDefinitionsList[*]}")
# Tidy: no longer needed
unset columnDefinitionsList

# Temporary file to contain only the essential columns
temp_selectData_file=${onsFolder}/tmp_selectData.csv

# The MySQL import command uses the filename minus extension as the basis for the table name like this:
tableName=$(basename ${temp_selectData_file} .csv)

# Create a table definition around the columns
tableDefinition="CREATE TABLE ${tableName} (DEFINITIONS) engine=myisam comment 'Temporary table created by install postcode script. Created $(date)';"
tableDefinition="${tableDefinition/DEFINITIONS/${columnDefinitionsCsv}}"
#echo -e "#	Table definition: ${tableDefinition}"

# Drop the old table
${superMysql} -e"drop table if exists ${tableName}" ${externalDb}

# Create table
${superMysql} \
	--execute="${tableDefinition}" \
	${externalDb}


# Extract only necessary columns
# The ordering of the fields does not change from the source file.
echo "#	Creating temporary CSV file from essential columns"
cut --delimiter=, --fields=${selectFieldNumbersSortedCsv} ${ONSdataFile} > ${temp_selectData_file}

echo "#	Loading CSV file"

# Load the CSV file. Need to use root as website doesn't have LOAD DATA privilege.
# -ignore is needed as the Aug 2025 contained duplicates for e.g KY7 5TA
mysqlimport \
	--defaults-extra-file=${mySuperCredFile} \
	--host=localhost \
	--fields-optionally-enclosed-by='"' \
	--fields-terminated-by=',' \
	--lines-terminated-by="\n" \
	--ignore-lines=1 \
	--ignore \
	${externalDb} \
	${temp_selectData_file}

# Mysql command equivalent is:
#echo -e "#	load data infile '${temp_selectData_file}' ignore into table ${externalDb}.${tableName} fields terminated by ',' optionally enclosed by '\"' lines terminated by '\n' ignore 1 lines;"
## SHOW WARNINGS;

# Clean up
rm -f ${temp_selectData_file}

# Tidy extracted data into postcode table
${superMysql} ${externalDb} < newPostcodeTable.sql

# Create the partial and district postcodes
echo "#	Creating partial and district tables"
${superMysql} ${externalDb} < PartialPostcode.sql

# Label with installed date
installedDate=$(date +%F)
${superMysql} ${externalDb} -e "alter table map_postcode comment = 'UK postcodes from Office of National Statistics, installed ${installedDate}'"

# Park the original
mv ${ONSdataFile} ${ONSdataFile}.parked_$(date +%F)

# Confirm end of script
echo -e "#	All now installed $(date)"

# Return true to indicate success
:

# End of file
