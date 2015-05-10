#!/bin/bash
# Tested on Ubuntu 14.04 (View Ubuntu version using 'lsb_release -a')
# This script is idempotent - it can be safely re-run without destroying existing data
#
# Controls echoed output default to on
verbose=1

# http://ubuntuforums.org/showthread.php?t=1783298
usage()
{
    cat << EOF
    
SYNOPSIS
	$0 -h -q

OPTIONS
	-h Show this message
	-q Suppress helpful messages, error messages are still produced

DESCRIPTION
 	Checks whether there's is a new edition of routing data on the server identified by configuration settings.
	If so, it is downloaded to the local machine, checked and unpacked into the data/routing/ folder.
	The routing edition database is installed.
	If successful it prompts to use the switch-routing-edition.sh script to start using the new routing edition.
EOF
}

# Run as the cyclestreets user (a check is peformed after the config file is loaded).
# Requires password-less access to the import machine, using a public key.

# When in failover mode uncomment the next two lines:
#echo "# Skipping in failover mode"
#exit 1

quietmode()
{
    # Turn off verbose messages by setting this variable to the empty string
    verbose=
}


# http://wiki.bash-hackers.org/howto/getopts_tutorial
while getopts ":hq" option ; do
    case ${option} in
        h) usage; exit ;;
        q) quietmode ;;
	\?) echo "Invalid option: -$OPTARG" >&2 ; exit ;;
    esac
done

# Echo output only if the verbose option has been set
vecho()
{
	if [ "${verbose}" ]; then
		echo $1
	fi
}

### Stage 1 - general setup

# Avoid echo if possible as this generates cron emails
# echo "#	CycleStreets routing data installation $(date)"

# Ensure this script is NOT run as root (it should be run as the cyclestreets user, having sudo rights as setup by install-website)
if [ "$(id -u)" = "0" ]; then
    echo "#	This script must NOT be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

# Lock directory
lockdir=/var/lock/cyclestreets
mkdir -p $lockdir

# Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 9 || { vecho '#	An installation is already running' ; exit 1; }


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

# Use this to remove the ../
ScriptHome=$(readlink -f "${DIR}/..")

# Name of the credentials file
configFile=${ScriptHome}/.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x ${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file."
    exit 1
fi

# Load the credentials
. ${configFile}


## Main body of script

# Avoid echo if possible as this generates cron emails
vecho "#	$(date)	CycleStreets routing data installation"

# Ensure there is a cyclestreets user account
if [ ! id -u ${username} >/dev/null 2>&1 ]; then
	echo "# User ${username} must exist: please run the main website install script"
	exit 1
fi

# Ensure this script is run as cyclestreets user
if [ ! "$(id -nu)" = "${username}" ]; then
    echo "#	This script must be run as user ${username}, rather than as $(id -nu)."
    exit 1
fi

# Ensure the main website installation is present
if [ ! -d ${websitesContentFolder}/data/routing ]; then
	echo "# The main website installation must exist with subtree data/routing please run the main website install script"
	exit 1
fi


### Stage 2 - obtain the routing import definition

# Ensure import machine and definition file variables has been defined
if [ -z "${importMachineAddress}" -o -z "${importMachineEditions}" ]; then

	# Avoid echoing as these are called by a cron job
	echo "# An import machine with an editions folder must be defined in order to run an import"
	exit 1
fi

## Retrieve the routing definition file from the import machine
# Tolerate errors
set +e

# Read the folder of routing editions, one per line, newest first, getting first one
latestEdition=`ssh ${username}@${importMachineAddress} ls -1t ${importMachineEditions} | head -n1`

# Abandon if not found
if [ -z "${latestEdition}" ]; then
	echo "# No routing editions found on ${importMachineAddress}"
	exit 1
fi

# Check this edition is not already installed
if [ -d ${websitesContentFolder}/data/routing/${latestEdition} ]; then
	# Avoid echo if possible as this generates cron emails
	vecho "#	Edition ${latestEdition} is already installed."
	vecho "#	Remove file with: rm -r ${websitesContentFolder}/data/routing/${latestEdition}"
	vecho "#	... and database: drop database ${latestEdition};"
	exit 1
fi

#	Report finding
# Avoid echo if possible as this generates cron emails
vecho "#	Latest edition: ${latestEdition}"

# Useful binding
newImportDefinition=${websitesContentFolder}/data/routing/temporaryNewDefinition.txt

#	Copy definition file
scp ${username}@${importMachineAddress}:${importMachineEditions}/${latestEdition}/importdefinition.ini $newImportDefinition >/dev/null 2>&1
if [ $? -ne 0 ]; then
	# Avoid echo if possible as this generates cron emails
	vecho "#	The import machine file could not be retrieved; please check the 'importMachineAddress': ${importMachineAddress} and 'newImportDefinition': ${newImportDefinition} settings."
	exit 1
fi

# Stop on errors
set -e

# Get the required variables from the routing definition file; this is not directly executed for security
# Sed extraction method as at http://stackoverflow.com/a/1247828/180733
# NB the timestamp parameter is not really used yet in the script below
# !! Note: the md5Dump option (which loads the database from a mysqldump generated file, and is an alternative to the hotcopy option md5Tables) is not yet supported
timestamp=`sed -n                       's/^timestamp\s*=\s*\([0-9]*\)\s*$/\1/p'       $newImportDefinition`
importEdition=`sed -n               's/^importEdition\s*=\s*\([0-9a-zA-Z]*\)\s*$/\1/p' $newImportDefinition`
md5Tsv=`sed -n                             's/^md5Tsv\s*=\s*\([0-9a-f]*\)\s*$/\1/p'    $newImportDefinition`
md5Tables=`sed -n                       's/^md5Tables\s*=\s*\([0-9a-f]*\)\s*$/\1/p'    $newImportDefinition`

# Ensure the key variables are specified
if [ -z "$timestamp" -o -z "$importEdition" -o -z "$md5Tsv" -o -z "$md5Tables" ]; then
	echo "# The routing definition file does not contain all of timestamp,importEdition,md5Tsv,md5Tables"
	exit 1
fi

#	Ensure these variables match
if [ "$importEdition" != "$latestEdition" ]; then
	echo "# The import edition: $importEdition does not match the latest edition: $latestEdition"
	exit 1
fi


# Check to see if this routing database already exists
# !! Note: This line will appear to give an error such as: ERROR 1049 (42000) at line 1: Unknown database 'routing130701'
# but in fact that is the condition desired.
if ${superMysql} -e "use ${importEdition}"; then
	# Avoid echo if possible as this generates cron emails
	vecho "#	Stopping because the routing database ${importEdition} already exists."
	# Clean exit - because this is not an error, it is just that there is no new data available
	exit 0
fi

# Check to see if a routing data file for this routing edition already exists
newEditionFolder=${websitesContentFolder}/data/routing/${importEdition}
if [ -d ${newEditionFolder} ]; then
	vecho "#	Stopping because the routing data folder ${importEdition} already exists."
	exit 1
fi


### Stage 3 - get the routing files and check data integrity

# Begin the file transfer
echo "#	$(date)	CycleStreets routing data installation"
echo "#	$(date)	Transferring the routing files from the import machine ${importMachineAddress}"

# Create the folder
mkdir -p ${newEditionFolder}

# Move the temporary definition to correct place and name
mv ${newImportDefinition} ${newEditionFolder}/importdefinition.ini

#	Transfer the TSV file
scp ${username}@${importMachineAddress}:${importMachineEditions}/${importEdition}/tsv.tar.gz ${newEditionFolder}/

#	Hot-copied tables file
scp ${username}@${importMachineAddress}:${importMachineEditions}/${importEdition}/tables.tar.gz ${newEditionFolder}/

#	Sieve file
scp ${username}@${importMachineAddress}:${importMachineEditions}/${importEdition}/sieve.sql ${newEditionFolder}/

#	Note that all files are downloaded
echo "#	$(date)	File transfer stage complete"

# MD5 checks
if [ "$(openssl dgst -md5 ${newEditionFolder}/tsv.tar.gz)" != "MD5(${newEditionFolder}/tsv.tar.gz)= ${md5Tsv}" ]; then
	echo "#	Stopping: TSV md5 does not match"
	exit 1
fi
if [ "$(openssl dgst -md5 ${newEditionFolder}/tables.tar.gz)" != "MD5(${newEditionFolder}/tables.tar.gz)= ${md5Tables}" ]; then
	echo "#	Stopping: Tables md5 does not match"
	exit 1
fi


### Stage 4 - unpack and install the TSV files
cd ${newEditionFolder}
tar xf tsv.tar.gz

#	Clean up the compressed TSV data
rm tsv.tar.gz

### Stage 5 - create the routing database

# Narrate
echo "#	$(date)	Installing the routing database: ${importEdition}"

#	Create the database (which will be empty for now) and set default collation
${superMysql} -e "create database ${importEdition} default character set utf8 default collate utf8_unicode_ci;"
${superMysql} -e "ALTER DATABASE ${importEdition} COLLATE utf8_unicode_ci;"

#!# Hard-coded location
dbFilesLocation=/var/lib/mysql/

# Ensure the MySQL directory has been created
# Requires root permissions to check this and so sudo is used.
echo $password | sudo -S test -d ${dbFilesLocation}${importEdition}
if [ $? != 0 ]; then
   echo "#	$(date) !! The MySQL database does not seem to be installed in the expected location."
   exit 1
fi

# Unpack the database files, preserve permissions, verbose into mysql
echo $password | sudo -S tar xpvf tables.tar.gz -C ${dbFilesLocation}${importEdition}

# Remove the zip
rm tables.tar.gz

### Stage 6 - run post-install stored procedures

#	Load nearest point stored procedures
echo "#	$(date)	Loading nearestPoint technology"
${superMysql} ${importEdition} < ${websitesContentFolder}/documentation/schema/nearestPoint.sql

# Build the photo index
echo "#	$(date)	Building the photosEnRoute tables"
${superMysql} ${importEdition} < ${websitesContentFolder}/documentation/schema/photosEnRoute.sql
${superMysql} ${importEdition} -e "call indexPhotos(false,0);"

### Stage 7 - Finish

# Create a file that indicates the end of the script was reached - this can be tested for by the switching script
touch "${websitesContentFolder}/data/routing/${importEdition}/installationCompleted.txt"

# Report completion and next steps
echo "#	$(date) Installation completed, to switch routing service use: ${ScriptHome}/live-deployment/switch-routing-edition.sh ${importEdition}"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
