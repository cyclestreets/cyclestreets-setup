#!/bin/bash
# Installs POIs (places of interest) data from another host.
#
# This script is idempotent - it can be safely re-run without destroying existing data
#
# Run as the cyclestreets user (a check is peformed after the config file is loaded).
# Requires password-less access to the import machine, using a public key.

usage()
{
    cat << EOF
    
SYNOPSIS
	$0 -h -q -m email -p port [importHostname] [edition]

OPTIONS
	-h Show this message
	-m Take an email address as an argument - notifies this address if a full installation starts.
	-p Take a port as argument which is used in ssh and scp connections with the import host.
	-q Suppress helpful messages, error messages are still produced


ARGUMENTS
	importHostname
		A hostname eg machinename.cyclestreets.net, as provided else read from config.

	edition
		The optional second argument can also be read from the config.
		It identifies either a dated routing edition of the form routingYYMMDD e.g. routing161012, or an alias.
		An alias should be a symlink to a dated routing edition.
		If not specified, it defaults to 'pois'.

DESCRIPTION
 	Checks whether there's is a new edition of pois data on the importHostname.
	If so, it is downloaded to the local machine, checked and unpacked into the data/routing/ folder.
	The tables are loaded into the external database and replace the existing POI tables there.

	The -p option is to support non-standard ssh port connections, e.g. -p5258 to connect to an IPv6 only server via and IPv4 interface.

	Secure shell access is required to the importHostname which can be setup as shown in the help for the install-routing-data.sh script.
EOF
}

# Controls echoed output default to on
verbose=1

# Default to no notification
notifyEmail=
sshPort=

# Files
tableGzip=table.tar.gz

# Default to this hardwired location - as live installs cannot expect the config option: importContentFolder
importMachineEditions=/websites/www/import/output

# Help for this BASH builtin: help getopts
# An opening colon in the option-string switches to silent error reporting mode.
# Colons after letters indicate that those options take an argument e.g. m takes an email address.
while getopts "hm:p:q" option ; do
    case ${option} in
        h) usage; exit ;;
	m)
	    # Set the notification email address
	    notifyEmail=$OPTARG
	    ;;
	p)
	    # Set the port
	    sshPort=$OPTARG
	    ;;
        q)
	    # Set quiet mode and proceed
	    # Turn off verbose messages by setting this variable to the empty string
	    verbose=
	    ;;
	:)
	    # Missing expected argument
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

    # Echo output only if the verbose option has been set
vecho()
{
	if [ "${verbose}" ]; then
		echo -e "# $(date)\t	$1"
	fi
}




# Bomb out if something goes wrong
set -e

# Lock directory
lockdir=/var/lock/cyclestreets
mkdir -p $lockdir

# Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 9 || { vecho 'An installation is already running, unlock with:\n#\tsudo rm /var/lock/cyclestreets/*.sh' ; exit 1; }


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
	desiredEdition=pois
    fi
fi

# There are only two arguments
if [ $# -gt 2 ]; then
	# Report and abandon
	echo -e "#\t	There is no support for more than two arguments." 1>&2
	exit 1
fi


# Check the source is OK
if [ -z "${importMachineEditions}" ]; then
    # Report and abandon
    echo "#	importMachineEditions is not valid" 1>&2
    exit 1
fi


# Port options: use -p with ssh and -P with scp
portSsh=
portScp=
if [ -n "${sshPort}" ]; then
    portSsh=-p$sshPort
    portScp=-P$sshPort
fi


## Main body of script

# Avoid echo if possible as this generates cron emails
vecho "CycleStreets POIs data installation"

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



### Stage 2 - Resolve the desired routing edition

# Ensure import machine and definition file variables has been defined
if [ -z "${importHostname}" -o -z "${importMachineEditions}" ]; then

	# Avoid echoing as these are called by a cron job
	vecho "An import machine with an editions folder must be defined in order to run an import"
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
# 2. Otherwise treat it as an alias which can be dereferenced.

# Examine the desiredEdition argument
if [[ "${desiredEdition}" =~ routing([0-9]{6}) ]]; then

    # It matches routingYYMMDD so use it directly
    resolvedEdition=${desiredEdition}
else
    # Cases when the format is not routingYYMMDD
    # Treat it as an alias and dereference to find the target edition
    resolvedEdition=$(ssh ${portSsh} ${username}@${importHostname} readlink -f ${importMachineEditions}/${desiredEdition})
    resolvedEdition=$(basename ${resolvedEdition})
fi

# Abandon if not found
if [ -z "${resolvedEdition}" ]; then
    vecho "The desired edition: ${desiredEdition} matched no routing editions on ${portSsh} ${importHostname}"
    exit 1
fi

# Double-check the routing edition format is correct
if [[ ! "${resolvedEdition}" =~ routing([0-9]{6}) ]]; then
    vecho "The desired edition: ${desiredEdition} resolved into: ${resolvedEdition} which is does not match routingYYMMDD."
    exit 1
fi


# Check this edition is not already installed
if [ -d ${websitesContentFolder}/data/routing/${resolvedEdition} ]; then
	# Avoid echo if possible as this generates cron emails
	vecho "Note the edition ${resolvedEdition} is already installed, proceeding with POIs installation."
fi

#	Report finding
# Avoid echo if possible as this generates cron emails
vecho "Resolved edition: ${resolvedEdition}"


# Useful bindings
# The defaults-extra-file is a positional argument which must come first.
superMysql="mysql --defaults-extra-file=${mySuperCredFile} -hlocalhost"
superMysqlImport="mysqlimport --defaults-extra-file=${mySuperCredFile} -hlocalhost"
smysqlshow="mysqlshow --defaults-extra-file=${mySuperCredFile} -hlocalhost"
externalDb=csExternal

# Check to see if that the external database already exists
if ! ${smysqlshow} | grep "\b${externalDb}\b" > /dev/null 2>&1
then
    # Avoid echo if possible as this generates cron emails
    vecho "Stoppping because the external database ${externalDb} does not exist."
    exit 1
fi

# Check to see if a routing data file for this routing edition already exists
newEditionFolder=${websitesContentFolder}/data/routing/${resolvedEdition}
if [ -d ${newEditionFolder} ]; then
	vecho "Note that the routing data folder ${resolvedEdition} already exists, proceeding with POIs installation."
fi



## Download

# Useful bindings
routingFolder=${websitesContentFolder}/data/routing
neTarball=${resolvedEdition}.tar.gz
neTarballMd5=${neTarball}.md5

# Begin the file transfer
vecho "Transferring the routing files from the import machine ${importHostname}"

#	Copy md5 file
scp ${portScp} ${username}@${importHostname}:${importMachineEditions}/${neTarballMd5} $routingFolder > /dev/null 2>&1
if [ $? -ne 0 ]; then
	# Avoid echo if possible as this generates cron emails
	vecho "The import machine file could not be retrieved from:\n#\t${portScp} ${username}@${importHostname}:${importMachineEditions}/${neTarballMd5}\n#\tCopying to: ${routingFolder}."
	exit 1
fi
#	Copy tarball file
scp ${portScp} ${username}@${importHostname}:${importMachineEditions}/${neTarball} $routingFolder > /dev/null 2>&1
if [ $? -ne 0 ]; then
	# Avoid echo if possible as this generates cron emails
	vecho "The import machine file could not be retrieved from:\n#\t${portScp} ${username}@${importHostname}:${importMachineEditions}/${neTarball}\n#\tCopying to: ${routingFolder}."
	exit 1
fi

#	Note that all files are downloaded
vecho "File transfer stage complete"



### Stage 3 - check data integrity

# MD5 check
cd $routingFolder
md5sum ${quietLongOption} -c ${neTarballMd5}
if [ $? -ne 0 ]; then
	# Avoid echo if possible as this generates cron emails
	vecho "Failed md5 check: md5sum -c $routingFolder/${neTarballMd5}"
	exit 1
fi

# Stop on errors
set -e

# Notify that an installation has begun
if [ -n "${notifyEmail}" ]; then
    echo "Routing edition installationfrom ${importHostname} is starting: this may lead to disk hiatus and concomitant notifications on the server ${csHostname} in about an hour." | mail -s "Import install has started on ${csHostname}" "${notifyEmail}"
fi

# Create the folder
mkdir -p ${newEditionFolder}


### Stage 4 - unpack and install the TSV files
vecho "Unpack the tarball"
tar xf ${neTarball}

#	Clean up the compressed TSV data
rm -f ${neTarball} ${neTarballMd5}

### Stage 5 - create the routing database

# Narrate
vecho "Installing into the external database: ${externalDb}"

# Go to the edition folder
cd ${newEditionFolder}

#	Load table definisions
${superMysql} ${externalDb} < table/tableDefinitions.sql

#	Import the data
find ${newEditionFolder}/table -name '*.tsv' -type f -print | xargs ${superMysqlImport} ${externalDb}

#	Rename the tables
${superMysql} ${externalDb} < installPoiTables.sql

#	Clean up
rm -r ${newEditionFolder}/table
rm -f ${newEditionFolder}/installPoiTables.sql


### Stage 7 - Finish


# Create a file that indicates the end of the script was reached - this can be tested for by the switching script
touch "${newEditionFolder}/installationCompleted.txt"

# Report completion and next steps
vecho "POIs Installation completed"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
