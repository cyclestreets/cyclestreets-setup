#!/bin/bash
# Script to do a check if a new planet file exists
usage()
{
    cat << EOF

SYNOPSIS
	$0 -h -q planetMd5url

OPTIONS
	-h Show this message
	-q Suppress helpful messages, error messages are still produced
	-r Resets the files that block retries on the same day.

ARGUMENTS
	planetMd5url
		URL of planet MD5 file.

DESCRIPTION
	Check if a new planet file is ready for download.
	If an error occurs return false.
	If a new build has already been done today then return false.
	If there is no new build available return false.
	Return value is true otherwise.
EOF
}

# Controls echoed output default to on
verbose=1

# Subfolder used to keep files to manage the checking
subfolder=dailybuild

# Files that record the date the latest build was done and today's date
dateFileLatestBuild=date-cyclestreets-latest-build.txt
dateFileTodaysDate=date-cyclestreets-today.txt

# Used to flag requirement to reset files that block retries on the same day
resetBlocker=

# Last used planet md5
planetMd5LatestBuild=planetLatestBuild.md5


# http://wiki.bash-hackers.org/howto/getopts_tutorial
# An opening colon in the option-string switches to silent error reporting mode.
# Colons after letters indicate that those options take an argument e.g. m takes an email address.
while getopts "hqr" option ; do
    case ${option} in
        h) usage; exit ;;
	# Set quiet mode and proceed
        q)
	    # Turn off verbose messages by setting this variable to the empty string
	    verbose=
	    ;;
        r)
	    # Set reset flag
	    resetBlocker=1
	    ;;
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

# Set quiet option variables when not verbose
quietOption=
quietLongOption=
if [ -z "${verbose}" ]; then
    quietOption=-1
    quietLongOption=--quiet
fi

# Helper function
# Echo output only if the verbose option has been set
vecho()
{
	if [ "${verbose}" ]; then
		echo -e $1
	fi
}



### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The second single line solution from that page is probably good enough as it is unlikely that this script itself will be symlinked.
ScriptHome="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Change to the script's folder
cd ${ScriptHome}

# Name of the credentials file
configFile=${ScriptHome}/.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x ${configFile} ]; then
    echo -e "#\tThe config file, ${configFile}, does not exist or is not executable. Copy your own based on the ${configFile}.template file, or create a symlink to the configuration."
    exit 1
fi

# Load the credentials
. ${configFile}


### Main body of script ###

# Bomb out if something goes wrong
set -e

## Start
vecho "#\t	Starting $0"

# Check number of arguments
if [ $# -eq 0 ]; then
    vecho "#\t	A url argument is required."
    exit 1
fi


# Check compulsory argument
if [ -n "$1" ]; then
    planetMd5url=$1
fi


# Create subfolder if not exists
if [ ! -d $subfolder ]; then
    mkdir -p $subfolder
    echo "Files used by $0 to manage downloads of latest planet data." > $subfolder/readme.txt
fi
cd $subfolder


# Check variables are non zero
if [ -z "${dateFileLatestBuild}" ]; then
    vecho "#\t	Variable: dateFileLatestBuild is empty"
    exit 1
fi
if [ -z "${dateFileTodaysDate}" ]; then
    vecho "#\t	Variable: dateFileTodaysDate is empty"
    exit 1
fi
if [ -z "${planetMd5url}" ]; then
    vecho "#\t	Variable: planetMd5url is empty"
    exit 1
fi
# Planet md5 file to check
planetMd5basename=`(basename $planetMd5url)`
if [ -z "${planetMd5basename}" ]; then
    vecho "#\t	Variable: planetMd5basename is empty"
    exit 1
fi
if [ -z "${planetMd5LatestBuild}" ]; then
    vecho "#\t	Variable: planetMd5LatestBuild is empty"
    exit 1
fi


# Create if not exists
if [ -n "${resetBlocker}" ]; then
    vecho "#\t	Resetting all files that block a retry today"
    rm $dateFileLatestBuild
    rm $planetMd5LatestBuild
    rm $dateFileTodaysDate
    vecho "#\t	Cleared ready for a retry."
    exit 0
fi



# Create if not exists
vecho "#\t	Record date of latest build"

# Get latest routing database based on remove-routing-edition.sh
# Find editions not including the null edition, or the modify graph edition
selector="from INFORMATION_SCHEMA.SCHEMATA where SCHEMA_NAME not in ('routing000000', 'routing220000') and SCHEMA_NAME LIKE 'routing%'"

# Useful binding
# The defaults-extra-file is a positional argument which must come first.
superMysql="mysql --defaults-extra-file=${mySuperCredFile} -hlocalhost"

# Determine newest edition not including the null edition (the -s suppresses the tabular output)
latestEdition=$(${superMysql} -s cyclestreets<<<"SELECT SCHEMA_NAME ${selector} order by SCHEMA_NAME desc limit 1;")

# Check the format is routingYYMMDD
if [[ ! "$latestEdition" =~ routing([0-9]{6}) ]]; then
  vecho "#\t	The latest edition found: ${latestEdition} is not of the form routingYYMMDD."
  exit 1
fi

# Extract the date part of the routing database
latestEditionDate=${BASH_REMATCH[1]}

# Write to file
echo $latestEditionDate > $dateFileLatestBuild

# Today's date
echo `date +%y%m%d` > $dateFileTodaysDate


# If a build has already been done today then abandon
if cmp -s $dateFileTodaysDate $dateFileLatestBuild
then
    vecho "#\t	A build has already been started today. Use -r option to reset and try again."
    exit 1
else
    vecho "#\t	The possibility of doing a new build will be examined."
fi

# Download
vecho "#\t	Downloading: $planetMd5url"

# Use -N to avoid download if not modified
wget -N ${quietLongOption} $planetMd5url

# Create if not exists
if [ ! -e $planetMd5LatestBuild ]; then
    vecho "#\t	Creating dummy file to record md5 of last planet file used to create a new routing edition"
    echo 'DummyMD5 data' > $planetMd5LatestBuild
fi

# Compare downloaded MD5 with the md5 last used in a build
if cmp -s $planetMd5basename $planetMd5LatestBuild
then
    vecho "#\t	The latest planed MD5 matches the one previously downloaded, so no new build should be done."
    exit 1
fi

# Report that a new build can be tried
vecho "#\t	The latest planet differs from the one used in a build, hence a new build can be tried."

# Overwrite the md5 to block re-entry
cp $planetMd5basename $planetMd5LatestBuild


## Finish
vecho "#\t	Finished $0"

# Indicates safe exit
:
