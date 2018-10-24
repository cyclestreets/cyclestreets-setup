#!/bin/bash
# Script to do a new CycleStreets import run, install and test it

# http://ubuntuforums.org/showthread.php?t=1783298
usage()
{
    cat << EOF
    
SYNOPSIS
	$0 -h -q -r -m email

OPTIONS
	-h Show this message
	-m Take an email address as an argument - for notifications when the build breaks or completes.
	-q Suppress helpful messages, error messages are still produced
	-r Removes the oldest routing edition

ARGUMENTS
	None
		Template used to describe argument.

DESCRIPTION
 	Starts a new build, including install and testing.

EOF
}

# Controls echoed output default to on
verbose=1
# By default do not remove oldest routing edtion
removeOldest=
# Default to no notification
notifyEmail=


# http://wiki.bash-hackers.org/howto/getopts_tutorial
# An opening colon in the option-string switches to silent error reporting mode.
# Colons after letters indicate that those options take an argument e.g. m takes an email address.
while getopts "hm:qr" option ; do
    case ${option} in
        h) usage; exit ;;
	m)
	    # Set the notification email address
	    notifyEmail=$OPTARG
	    ;;
	# Remove oldest routing edition
	r) removeOldest=1
	   ;;
	# Set quiet mode and proceed
        q)
	    # Turn off verbose messages by setting this variable to the empty string
	    verbose=
	    ;;
	# Missing expected argumnet
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
    echo -e "#\tThe config file, ${configFile}, does not exist or is not excutable. Copy your own based on the ${configFile}.template file, or create a symlink to the configuration."
    exit 1
fi

# Load the credentials
. ${configFile}


### Main body of script ###

# Bomb out if something goes wrong
set -e

## Start
vecho "#\tStarting $0"


## Optionally remove oldest routing edtion
if [ "${removeOldest}" ]; then
    live-deployment/remove-routing-edition.sh oldest
fi


## Import (the force overrides the current edition if it is for the same date)
if import-deployment/import.sh force ;
then
    vecho "#\t$(date)\tImport completed just fine."
else

    # Gather a report and send it
    if [ -n "${notifyEmail}" ]; then

	# Generate a build error report
	reportFile=import/buildError.txt
	echo -e "#\tBuild stopped during import script\n" > ${reportFile}

	# Append last lines of import log
	tail -n80 import/log.txt >> ${reportFile}
	echo -e "#\n#\tYours,\n#\t\t\t${0##*/}" >> ${reportFile}

	# Send report
	cat ${reportFile} | mail -s "${csHostname} import stopped" "${notifyEmail}"
    else
	vecho "Build stopped during import script"
    fi
    exit 1
fi


## Install
if live-deployment/installLocalLatestEdition.sh ;
then
    vecho "#\t$(date)\tLocal install completed just fine."
else
    if [ -n "${notifyEmail}" ]; then
	echo "During install local lastest edition" | mail -s "${csHostname} import stopped" "${notifyEmail}"
    else
	vecho "Import stopped during install local lastest edition"
    fi
    exit 2
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

# Append last few lines of import log
tail -n3 import/log.txt >> ${summaryFile}

# Run tests relevant to the new build, appending to summary
php runtests.php "call=nearestpoint" >> ${summaryFile}
php runtests.php "call=journey" >> ${summaryFile}
# Compare new coverage with when the elevation.values auto tests were created
php runtests.php "call=elevation.values&name=Elevation auto generated test:" >> ${summaryFile}

# Sign off
echo -e "#\n#\tYours,\n#\t\t\t${0##*/}" >> ${summaryFile}

# Mail summary
if [ -n "${notifyEmail}" ]; then

    # Send last lines of log and test results
    cat ${summaryFile} | mail -s "${csHostname} import finished" "${notifyEmail}"

fi

# Report
cat ${summaryFile}

## Finish
vecho "#\tFinished $0"

# Indicates safe exit
:
