#!/bin/bash
# Script to deploy CycleStreets backup on Ubuntu
# Tested on 12.10 (View Ubuntu version using 'lsb_release -a')
# This script is idempotent - it can be safely re-run without destroying existing data

echo "#	CycleStreets backup deployment $(date)"

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
    echo "#	The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. ${configFile}

# Load helper functions
. ${ScriptHome}/utility/helper.sh

# Main body of script

# Install the website
# !! Turned off for testing
# !! Backup machine may also need different config options for the server - needs checking
#. ../install-website/run.sh

# Cron jobs
if $installCronJobs ; then

    # Update scripts
    installCronJob ${username} "25 6 * * * cd ${ScriptHome} && git pull -q"

    # Backup data every day at 5:05 am
    installCronJob ${username} "5 5 * * * ${ScriptHome}/fallback-deployment/daily-update.sh"

    # Hourly zapping at 13 mins past every hour
    installCronJob ${username} "13 * * * * ${ScriptHome}/utility/remove-tempgenerated.sh"

    # Hourly backup of Cyclescape
    installCronJob ${username} "42 7 * * * ${ScriptHome}/fallback-deployment/cyclescapeDownloadAndRotateDaily.sh"

    # Daily download of Cyclestreets Dev - subversion repo and trac
    installCronJob ${username} "19 9 * * * ${ScriptHome}/fallback-deployment/csDevDownloadAndRotateDaily.sh"

    # Daily rotate of Cyclescape
    installCronJob ${username} "26 8 * * * ${ScriptHome}/fallback-deployment/cyclescapeRotateDaily.sh"

    # Daily rotate of Cyclestreets
    installCronJob ${username} "39 8 * * * ${ScriptHome}/fallback-deployment/cyclestreetsRotateDaily.sh"

    # Daily update of code base and clearout of old routing files at 9:49am
    installCronJob ${username} "49 9 * * * ${ScriptHome}/utility/backup-maintenance.sh"

    # Weekly rotation of backups
    installCronJob ${username} "50 10 * * 7 ${ScriptHome}/fallback-deployment/cyclestreetsRotateWeekly.sh"
fi

# Confirm end of script
echo -e "#	All now deployed $(date)"

# End of file
