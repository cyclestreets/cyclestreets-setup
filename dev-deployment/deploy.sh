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

# Ensure there's a custom sudoers file
# !! Note: on the dev machine (which dates back to about 2008) the sudoers.d folder was not automatically included, so had to be added manually.
if [ -n "${csSudoers}" -a ! -e "${csSudoers}" ]; then

    # !! Potentially add more checks to these sudoers expressions, such as ensuring the commands include their full paths.

    # Create a file that provides passwordless sudo access svnadmin - which needs root access because some files are read able only by www-data
    # Note: the csSudoers var was created for other deployments and this is a bit of an appropriation of that var and file.
    # It would be a little cleaner for it to have its own var, but on a dev deployment it is not used for anything else.
    cat > ${csSudoers} << EOF
# Dev deployment
# Permit cyclestreets user to dump svn without a password
cyclestreets ALL = (root) NOPASSWD: /usr/bin/svnadmin
EOF

    # Make it read only
    chmod 440 ${csSudoers}
fi

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
