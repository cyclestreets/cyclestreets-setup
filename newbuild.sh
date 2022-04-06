#!/bin/bash
# Script to do a new CycleStreets import run, install and test it
usage()
{
    cat << EOF
    
SYNOPSIS
	$0 -h -q -r -s -m email [config]

OPTIONS
	-h Show this message
	-m Take an email address as an argument - for notifications when the build breaks or completes
	-q Suppress helpful messages, error messages are still produced
	-r Removes the oldest routing edition
	-s Builds and switches secondary routing edition, removing previous one

ARGUMENTS
	[config]
		Optional configuration file or symlink to one.
		When a symlink is provided it's basename is used as an alias to create symlink to the output routing edtion.

DESCRIPTION
	Builds a new routing edition, installs on the local server, and runs tests, optionally emailing results.

EOF
}

# Controls echoed output default to on
verbose=1
# By default do not remove oldest routing edtion
removeOldest=
# Default to no notification
notifyEmail=
# Secondary edition
secondaryEdition=
# Routing edition alias: a folder name which is used as a symlink e.g. centralLondon or custom641
editionAlias=

# http://wiki.bash-hackers.org/howto/getopts_tutorial
# An opening colon in the option-string switches to silent error reporting mode.
# Colons after letters indicate that those options take an argument e.g. m takes an email address.
while getopts "hm:qrs" option ; do
    case ${option} in
        h) usage; exit ;;
	m)
	    # Set the notification email address
	    notifyEmail=$OPTARG
	    ;;
	# Remove oldest routing edition
	r) removeOldest=1
	   ;;
	# Secondary edtion
	s) secondaryEdition=1
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
vecho "#\tStarting $0"


# Check optional argument
if [ -n "$1" ]; then
    importConfig=$1
else
    # Set default
    importConfig=${importContentFolder}/.config.php
fi

# Dereference any symlink
if [ -L "${importConfig}" ]; then
    # Use the symlink as the alias for the edition
    editionAlias=`basename ${importConfig}`
    importConfig=`readlink ${importConfig}`
fi

# Import type
# The type of the import can be determined either from the alias, the basename of the config file
# or failing that the full path of the config file
importTitle=
# Use alias if present
if [ -n "${editionAlias}" ]; then
    importTitle=${editionAlias}
else
    # Use the basename
    importTitle=`basename ${importConfig}`

    # If the basename matches the default then use the full path
    if [ "${importTitle}" = ".config.php" ]; then
	importTitle=${importConfig}
    fi
fi

## Optionally remove oldest routing edtion
if [ "${removeOldest}" ]; then
    live-deployment/remove-routing-edition.sh oldest
fi

## Import (the -f overrides the current edition if it is for the same date)
if import-deployment/import.sh -f $importConfig;
then
    vecho "#\t$(date)\tImport completed just fine."
else

    # Gather a report and send it
    if [ -n "${notifyEmail}" ]; then

	# Generate a build error report
	reportFile=${ScriptHome}/buildError.txt
	echo -e "#\tBuild stopped during import script as follows." > ${reportFile}
	echo -e "#\n#\n#\tYours,\n#\t\t\t${0##*/}\n\n" >> ${reportFile}

	# Append last lines of import log
	tail -n50 ${importContentFolder}/log.txt >> ${reportFile}

	# Send report
	cat ${reportFile} | mail -s "${csHostname} import stopped" "${notifyEmail}"
    else
	vecho "#\tBuild stopped during import script"
    fi
    exit 1
fi

# Useful binding
# The defaults-extra-file is a positional argument which must come first.
superMysql="mysql --defaults-extra-file=${mySuperCredFile} -hlocalhost"

# Determine latest edition (the -s suppresses the tabular output)
newEdition=$(${superMysql} -s cyclestreets<<<"SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME LIKE 'routing%' order by SCHEMA_NAME desc limit 1;")
vecho "#\tNew edition: ${newEdition}"

# Optionally create an alias for the routing edtion
if [ -n "${editionAlias}" ]; then

    # The new routing edition will be written to this location
    importMachineEditions=${importContentFolder}/output

    # Remove any existing link
    rm -f ${importMachineEditions}/${editionAlias}

    # Create a symlink to the new edition - this allows remote machines to install the edition using the alias
    ln -s ${importMachineEditions}/${newEdition} ${importMachineEditions}/${editionAlias}
    vecho "#\tAlias: ${editionAlias}"
fi

## Install
if live-deployment/installLocalLatestEdition.sh newEdition ;
then
    vecho "#\t$(date)\tLocal install completed just fine."
else
    if [ -n "${notifyEmail}" ]; then
	echo "During install local lastest edition" | mail -s "${csHostname} import stopped" "${notifyEmail}"
    else
	vecho "#\tImport stopped during install local lastest edition"
    fi
    exit 2
fi

## Secondary editions require manual completion
if [ "${secondaryEdition}" ]; then
    echo "$0 Secondary edition: Complete the installation from the command line"
    live-deployment/switch-secondary-edition.sh
    exit 0
fi

## Switch
if live-deployment/switch-routing-edition.sh ;
then
    vecho "#\t$(date)\tSwitch routing edition completed just fine."
else
    if [ -n "${notifyEmail}" ]; then
	echo "During switch routing edition" | mail -s "${csHostname} import stopped" "${notifyEmail}"
    else
	vecho "#\t$(date)\tImport stopped during switch routing edition"
    fi
    exit 3
fi


## Test the built routing edition
cd "${websitesContentFolder}"

# Generate Build Summary message
summaryFile=import/buildSummary.txt
echo -e "#\tBuild summary" > ${summaryFile}
echo -e "#\tConfig file: ${importConfig}" >> ${summaryFile}

# Append last few lines of import log
tail -n3 import/log.txt >> ${summaryFile}

# Run tests relevant to the new build, appending to summary
php runtests.php "call=nearestpoint" >> ${summaryFile}
php runtests.php "call=journey&apiVersion=1" >> ${summaryFile}
php runtests.php "call=journey&apiVersion=2" >> ${summaryFile}
# Compare new coverage with when the elevation.values auto tests were created
php runtests.php "call=elevation.values&name=Elevation auto generated test:" >> ${summaryFile}

# Mail summary
if [ -n "${notifyEmail}" ]; then

    # Send last lines of log and test results
    cat ${summaryFile} | mail -s "${csHostname} import ${importTitle} finished" "${notifyEmail}"

fi

# Report
cat ${summaryFile}

## Finish
vecho "#\tFinished $0"

# Indicates safe exit
:
