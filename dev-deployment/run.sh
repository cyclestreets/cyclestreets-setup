#!/bin/bash
# Script to deploy CycleStreets Dev scripts on Ubuntu
# Tested on 12.10 (View Ubuntu version using 'lsb_release -a')
# This script is idempotent - it can be safely re-run without destroying existing data

echo "#	CycleStreets Dev machine deployment $(date)"

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

# Cron jobs
if $installCronJobs ; then

    # Update scripts
    jobs[1]="25 6 * * * cd ${ScriptHome} && git pull -q"

    # Backup data every day at 6:26 am
    jobs[2]="26 6 * * * ${ScriptHome}/dev-deployment/dailybackup.sh"

    # SMS monitoring every 5 minutes
    jobs[3]="0,5,10,15,20,25,30,35,40,45,50,55 * * * * php ${ScriptHome}/sms-monitoring/run.php"

    # Install the jobs
    installCronJobs ${username} jobs[@]
fi

# Confirm end of script
echo -e "#	All now deployed $(date)"

# End of file
