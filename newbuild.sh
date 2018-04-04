#!/bin/bash
# Script to do a new CycleStreets import run, install and test it
# Controls echoed output default to on
verbose=1
# By default do not remove oldest routing edtion
removeOldest=0

# http://ubuntuforums.org/showthread.php?t=1783298
usage()
{
    cat << EOF
    
SYNOPSIS
	$0 -h -q -r

OPTIONS
	-h Show this message
	-q Suppress helpful messages, error messages are still produced
	-r Removes the oldest routing edition

ARGUMENTS
	None
		Template used to describe argument.

DESCRIPTION
 	Starts a new build, including install and testing.

EOF
}

# http://wiki.bash-hackers.org/howto/getopts_tutorial
# An opening colon in the option-string switches to silent error reporting mode.
# Colons after letters indicate that those options take an argument e.g. m takes an email address.
while getopts "hqr" option ; do
    case ${option} in
        h) usage; exit ;;
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
		echo $1
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
    echo "#	The config file, ${configFile}, does not exist or is not excutable. Copy your own based on the ${configFile}.template file, or create a symlink to the configuration."
    exit 1
fi

# Load the credentials
. ${configFile}


### Main body of script ###

# Start
vecho "#	Starting newbuild.sh"
cd /opt/cyclestreets-setup/

# Optionally remove oldest routing edtion
if [ "${removeOldest}" ]; then
    live-deployment/remove-routing-edition.sh oldest
fi

# Import (the force overrides the current edition if it is for the same date)
if import-deployment/import.sh force ;
then
    vecho "#	$(date)	Import completed just fine."
else
    vecho "Import stopped during import script"
    exit 1
fi

# Install
if live-deployment/installLocalLatestEdition.sh ;
then
    vecho "#	$(date)	Local install completed just fine." 
else
    vecho "Import stopped during install local lastest edition"
    exit 2
fi

# Switch
if live-deployment/switch-routing-edition.sh ;
then
    vecho "#	$(date)	Switch routing edition completed just fine." 
else
    vecho "Import stopped during switch routing edition"
    exit 3
fi

# Test
cd "${websitesContentFolder}"

# Last 10 lines of import log
tail import/log.txt

# Run tests
php runtests.php "${csHostname}"

# Finish
vecho "#	Finish newbuild.sh"

# Indicates safe exit
:
