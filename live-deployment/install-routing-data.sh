#!/bin/bash
# Installs new editions of cycle routing data from another host.
#
# This script is idempotent - it can be safely re-run without destroying existing data

# Controls echoed output default to on
verbose=1

usage()
{
    cat << EOF
    
SYNOPSIS
	$0 -h -q -s -t -m email [importHostname] [edition] [path]

OPTIONS
	-h Show this message
	-m Take an email address as an argument - notifies this address if a full installation starts.
	-q Suppress helpful messages, error messages are still produced
	-r Removes the oldest routing edition
	-s Skip switching to new edition
	-t Does a dry run showing the resolved options

ARGUMENTS
	importHostname
		A hostname eg machinename.cyclestreets.net, as provided else read from config.

	edition
		The optional second argument can also be read from the config.
		It identifies either a dated routing edition of the form routingYYMMDD e.g. routing161012, or an alias.
		If not specified, it defaults to 'latest', the edition on the host having the most recent date.
		It can also name an alias that symlinks to a dated routing edition.
	path (deprecated)
		The optional third argument (a non slash terminated directory path) says where on the host the routing edition can be found.
		Defaults to the hardwired location: /websites/www/import/output
		This argument is deprecated in favour of using aliases for the edition argument.

DESCRIPTION
 	Checks whether there's is a new edition of routing data on the importHostname.
	If so, it is downloaded to the local machine, checked and unpacked into the data/routing/ folder.
	The routing edition database is installed.
	If successful it prompts to use the switch-routing-edition.sh script to start using the new routing edition.

	Secure shell access is required to the importHostname which can be setup as follows:
# cyclestreets@machinename1:~$
ssh-keygen
# accept defaults ie: suggested file and no passphrase

# Copy to the importHostname eg:
ssh-copy-id -i ~/.ssh/id_rsa.pub machinename2.cyclestreets.net

EOF
}

# Run as the cyclestreets user (a check is peformed after the config file is loaded).
# Requires password-less access to the import machine, using a public key.

# Default to no notification
notifyEmail=
testargs=

# By default do not remove oldest routing edtion
removeOldest=
# Default to switch to the new edition when this is empty
skipSwitch=

# Files
tsvFile=tsv.tar.gz
dumpFile=dump.sql.gz

# http://wiki.bash-hackers.org/howto/getopts_tutorial
# An opening colon in the option-string switches to silent error reporting mode.
# Colons after letters indicate that those options take an argument e.g. m takes an email address.
while getopts "hm:qrst" option ; do
    case ${option} in
        h) usage; exit ;;
	m)
	    # Set the notification email address
	    notifyEmail=$OPTARG
	    ;;
	# Remove oldest routing edition
	r) removeOldest=1
	   ;;
	# Skip switching to the new edition
	s)
	    skipSwitch=1
	   ;;
	# Dry run shows results of arg processing
	t)
	    testargs=test
	   ;;
	# Set quiet mode and proceed
        q)
	    # Turn off verbose messages by setting this variable to the empty string
	    verbose=
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

# Echo output only if the verbose option has been set
vecho()
{
	if [ "${verbose}" ]; then
		echo -e $1
	fi
}




# Bomb out if something goes wrong
set -e

# Lock directory
lockdir=/var/lock/cyclestreets
mkdir -p $lockdir

# Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 9 || { vecho '#\tAn installation is already running' ; exit 1; }


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
    echo "#	The config file, ${configFile}, does not exist or is not executable - copy your own based on the ${configFile}.template file."
    exit 1
fi

# Load the credentials
. ${configFile}


### Stage 1 - general setup

# Ensure this script is NOT run as root (it should be run as the cyclestreets user, having sudo rights as setup by install-website)
if [ "$(id -u)" = "0" ]; then
    echo "#	This script must NOT be run as root." 1>&2
    exit 1
fi

## Optionally remove oldest routing edtion
if [ "${removeOldest}" ]; then
    ${ScriptHome}/live-deployment/remove-routing-edition.sh oldest
fi

# Optional first argument is the source of the new routing editions
if [ $# -gt 0 ]; then
    # Use as supplied
    importHostname=$1
else
    # Check a value was provided by the config
    if [ -z "${importHostname}" ]; then
	# Report and abandon
	echo "#	Import host name must be provided as an argument or in the config." 1>&2
	exit 1
    fi
fi

# Optional second argument 'edition' names the desired routing edition
if [ $# -gt 1 ]; then
    # Use as supplied
    desiredEdition=$2
else
    # When no value is provided by the config set a default
    if [ -z "${desiredEdition}" ]; then
	# Default
	desiredEdition=latest
    fi
fi

# Optional third argument 'path' says where on the host the routing edition can be found
if [ $# -gt 2 ]; then
    # Use supplied location
    importMachineEditions=$3
else
    # Default to this hardwired location - as live installs cannot expect the config option: importContentFolder
    importMachineEditions=/websites/www/import/output
fi

# Check the source is OK
if [ -z "${importMachineEditions}" ]; then
    # Report and abandon
    echo "#	importMachineEditions is not valid" 1>&2
    exit 1
fi


# Testargs: show argument resuolution
if [ -n "${testargs}" ]; then
    echo "#	Argument resolution";
    echo "#	\$#=${#}";
    echo "#	\$@=${@}";
    echo "#	\$0=${0}";
    echo "#	\$1=${1}";
    echo "#	\$2=${2}";
    echo "#	verbose=${verbose}";
    echo "#	notifyEmail=${notifyEmail}";
    echo "#	skipSwitch=${skipSwitch}";
    echo "#	dumpFile=${dumpFile}";
    echo "#	tsvFile=${tsvFile}";
    echo "#	importHostname=${importHostname}";
    echo "#	desiredEdition=${desiredEdition}";
    echo "#	importMachineEditions=${importMachineEditions}";
    exit 0
fi



## Main body of script

# Avoid echo if possible as this generates cron emails
vecho "#\t$(date) CycleStreets routing data installation"

# Ensure there is a cyclestreets user account
if [ ! id -u ${username} > /dev/null 2>&1 ]; then
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
if [ -z "${importHostname}" -o -z "${importMachineEditions}" ]; then

	# Avoid echoing as these are called by a cron job
	vecho "#\tAn import machine with an editions folder must be defined in order to run an import"
	exit 1
fi

## Retrieve the routing definition file from the import machine
# Tolerate errors
set +e

# importMachineEditions
# This is a folder of routing editions which have names of the form routingYYMMDD.
# Each edition is also a folder that contains all the data necessary to setup routing on another machine.
#
# The folder may also contain aliases that symlink to the dated edtions.
# The aliases are a way of naming routing editions that allows them to referred to generically.
#
# The script arguement desiredEdition is converted into an explicitly dated edition of the form routingYYMMDD, as follows:
# 1. If desiredEdition matches routingYYMMDD then use it directly.
# 2. If desiredEdition = "latest" then read the folder of editions and select the one with the newest date.
# 3. Otherwise treat it as an alias which can be dereferenced.

# Examine the desiredEdition argument
if [[ "${desiredEdition}" =~ routing([0-9]{6}) ]]; then

    # It matches routingYYMMDD so use it directly
    resolvedEdition=${desiredEdition}
else
    # Cases when the format is not routingYYMMDD
    if [ ${desiredEdition} == "latest" ]; then

	# Read the folder contents, one per line, sorted alphabetically, filtered to match routing editions, getting last one
	resolvedEdition=`ssh ${username}@${importHostname} ls -1 ${importMachineEditions} | grep "routing\([0-9]\)\{6\}" | tail -n1`

    else
	# Treat it as an alias and dereference to find the target edition
	resolvedEdition=$(ssh ${username}@${importHostname} readlink -f ${importMachineEditions}/${desiredEdition})
	resolvedEdition=$(basename ${resolvedEdition})
    fi
fi

# Abandon if not found
if [ -z "${resolvedEdition}" ]; then
    vecho "#\tThe desired edition: ${desiredEdition} matched no routing editions on ${importHostname}"
    exit 1
fi

# Double-check the format is routingYYMMDD
if [[ ! "${resolvedEdition}" =~ routing([0-9]{6}) ]]; then
    vecho "#\tThe desired edition: ${desiredEdition} resolved into: ${resolvedEdition} which is does not match routingYYMMDD."
    exit 1
fi


# Check this edition is not already installed
if [ -d ${websitesContentFolder}/data/routing/${resolvedEdition} ]; then
	# Avoid echo if possible as this generates cron emails
	vecho "#\tEdition ${resolvedEdition} is already installed."
	exit 1
fi

#	Report finding
# Avoid echo if possible as this generates cron emails
vecho "#\tResolved edition: ${resolvedEdition}"

# Useful binding
newImportDefinition=${websitesContentFolder}/data/routing/temporaryNewDefinition.txt

#	Copy definition file
scp ${username}@${importHostname}:${importMachineEditions}/${resolvedEdition}/importdefinition.ini $newImportDefinition > /dev/null 2>&1
if [ $? -ne 0 ]; then
	# Avoid echo if possible as this generates cron emails
	vecho "#\tThe import machine file could not be retrieved from:\n#\t${username}@${importHostname}:${importMachineEditions}/${resolvedEdition}/importdefinition.ini\n#\tCopying to: ${newImportDefinition}."
	exit 1
fi

# Stop on errors
set -e

# Get the required variables from the routing definition file; this is not directly executed for security
# Sed extraction method as at http://stackoverflow.com/a/1247828/180733
# NB the timestamp parameter is not really used yet in the script below
timestamp=`sed -n                   's/^timestamp\s*=\s*\([0-9]*\)\s*$/\1/p'           $newImportDefinition`
importEdition=`sed -n               's/^importEdition\s*=\s*\([0-9a-zA-Z]*\)\s*$/\1/p' $newImportDefinition`
md5Tsv=`sed -n                      's/^md5Tsv\s*=\s*\([0-9a-f]*\)\s*$/\1/p'           $newImportDefinition`
md5Dump=`sed -n                     's/^md5Dump\s*=\s*\([0-9a-f]*\)\s*$/\1/p'          $newImportDefinition`

# Ensure the key variables are specified
if [ -z "$timestamp" -o -z "$importEdition" -o -z "$md5Tsv" -o -z "$md5Dump" ]; then
	echo "# The routing definition file does not contain all of timestamp,importEdition,md5Tsv,md5Dump"
	exit 1
fi

#	Ensure these variables match
if [ "$importEdition" != "$resolvedEdition" ]; then
	echo "# The import edition: $importEdition does not match the desired edition: $resolvedEdition"
	exit 1
fi


# Useful binding
# The defaults-extra-file is a positional argument which must come first.
superMysql="mysql --defaults-extra-file=${mySuperCredFile} -hlocalhost"
smysqlshow="mysqlshow --defaults-extra-file=${mySuperCredFile} -hlocalhost"

# Check to see if this routing database already exists
if ${smysqlshow} | grep "\b${resolvedEdition}\b" > /dev/null 2>&1
then
	# Avoid echo if possible as this generates cron emails
	vecho "#\tStopping because the routing database ${importEdition} already exists."
	# Clean exit - because this is not an error, it is just that there is no new data available
	exit 0
fi

# Check to see if a routing data file for this routing edition already exists
newEditionFolder=${websitesContentFolder}/data/routing/${importEdition}
if [ -d ${newEditionFolder} ]; then
	vecho "#\tStopping because the routing data folder ${importEdition} already exists."
	exit 1
fi


### Stage 3 - get the routing files and check data integrity

# Notify that an installation has begun
if [ -n "${notifyEmail}" ]; then
    echo "Data transfer from ${importHostname} is starting: this may lead to disk hiatus and concomitant notifications on the server ${csHostname} in about an hour." | mail -s "Import install has started on ${csHostname}" "${notifyEmail}"
fi

# Begin the file transfer
echo "#	$(date)	CycleStreets routing data installation"
echo "#	$(date)	Transferring the routing files from the import machine ${importHostname}"

# Create the folder
mkdir -p ${newEditionFolder}

# Move the temporary definition to correct place and name
mv ${newImportDefinition} ${newEditionFolder}/importdefinition.ini

#	Sieve file (do first as it is the smallest)
scp ${username}@${importHostname}:${importMachineEditions}/${importEdition}/sieve.sql ${newEditionFolder}/

#	Transfer the TSV file
scp ${username}@${importHostname}:${importMachineEditions}/${importEdition}/${tsvFile} ${newEditionFolder}/

#	Mysql dump file
scp ${username}@${importHostname}:${importMachineEditions}/${importEdition}/${dumpFile} ${newEditionFolder}/

#	Note that all files are downloaded
echo "#	$(date)	File transfer stage complete"

# MD5 checks
if [ "$(openssl dgst -md5 ${newEditionFolder}/${tsvFile})" != "MD5(${newEditionFolder}/${tsvFile})= ${md5Tsv}" ]; then
	echo "#	Stopping: TSV md5 does not match"
	exit 1
fi
if [ "$(openssl dgst -md5 ${newEditionFolder}/${dumpFile})" != "MD5(${newEditionFolder}/${dumpFile})= ${md5Dump}" ]; then
    echo "#	Stopping: dump md5 does not match"
    exit 1
fi

### Pre stage 4: Close system to routing and stop the existing routing service
if [ -z "${keepRoutingDuringUpdate}" ]; then

    # Narrate
    echo "#	$(date)	Closing system to routing and stopping the existing routing service"

    # Close the journey planner
    ${superMysql} cyclestreets -e "call closeJourneyPlanner();";

    # Cycle routing stop command (should match passwordless sudo entry)
    routingServiceStop="/bin/systemctl stop cyclestreets"

    # Stop the routing service
    sudo ${routingServiceStop}
fi

### Stage 4 - unpack and install the TSV files
echo "#	$(date)	Unpack and install the TSV files"
cd ${newEditionFolder}
tar xf ${tsvFile}

#	Clean up the compressed TSV data
rm -f ${tsvFile}

### Stage 5 - create the routing database

# Narrate
echo "#	$(date)	Installing the routing database: ${importEdition}"

#	Create the database (which will be empty for now) and set default collation
${superMysql} -e "create database ${importEdition} default character set utf8mb4 default collate utf8mb4_unicode_ci;"

# Unpack and restore the database using the lowest possible priority to avoid interrupting the live server
gunzip < ${dumpFile} | ${superMysql} ${importEdition}

# Remove the zip
rm -f ${dumpFile}

### Stage 6 - run post-install stored procedures

#	Load nearest point stored procedures
echo "#	$(date)	Loading nearestPoint technology"
${superMysql} ${importEdition} < ${websitesContentFolder}/documentation/schema/nearestPoint.sql

# Build the photo index
echo "#	$(date)	Building the photosEnRoute tables"
${superMysql} ${importEdition} < ${websitesContentFolder}/documentation/schema/photosEnRoute.sql
${superMysql} ${importEdition} -e "call indexPhotos(0);"

### Stage 7 - Finish

# Add the new row to the map_edition table
if ! ${superMysql} --batch --skip-column-names -e "call addNewEdition('${importEdition}')" cyclestreets
then
    echo "#	$(date)	There was a problem adding the new edition: ${importEdition}. The import install did not complete."
    exit 1
fi

# Create a file that indicates the end of the script was reached - this can be tested for by the switching script
touch "${websitesContentFolder}/data/routing/${importEdition}/installationCompleted.txt"

# Report completion and next steps
echo "#	$(date)	Installation completed"

# Switch to the new edition
if [ -z "${skipSwitch}" ]; then
    echo "#	$(date) Switching to the new edition"
    ${ScriptHome}/live-deployment/switch-routing-edition.sh ${importEdition}
else
    echo "#	$(date) Switch to the new edition using: ${ScriptHome}/live-deployment/switch-routing-edition.sh ${importEdition}"
fi

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
