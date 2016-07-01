#!/bin/bash
# 
# SYNOPSIS
#	deploy.sh
#
# DESCRIPTION
#	Script to deploy a CycleStreets import system that has been installed by ../install-import/run.sh
#	All it does is to configure MySQL to be capabable of handling large imports, and optionally schedule some cron jobs.
#	Written for Ubuntu Server 16.04 LTS (View Ubuntu version using 'lsb_release -a')
#	This script is idempotent - it can be safely re-run without destroying existing data

echo "#	CycleStreets import deployment $(date)"

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#	This script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The second single line solution from that page is probably good enough as it is unlikely that this script itself will be symlinked.
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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

# Load helper functions
. ${ScriptHome}/utility/helper.sh

# Main body of script

# Cron jobs
if $installCronJobs ; then

    # Update scripts
    installCronJob ${username} "25 6 * * * cd ${ScriptHome} && git pull -q"

    # Import data every day
    installCronJob ${username} "0 10 * * * ${ScriptHome}/import-deployment/import.sh"
fi

# Confirm end of script
echo -e "#	All now deployed $(date)"

# End of file
