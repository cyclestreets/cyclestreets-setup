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


# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Main body of script

# Install the website
# !! Turned off for testing
# !! Backup machine may also need different config options for the server - needs checking
#. ../install-website/run.sh

# Cron jobs
if $installCronJobs ; then

    # Install the cron job here
    echo "#	Install cron jobs"

    # Backup data every day at 5:05 am
    jobs[1]="5 5 * * * ${ScriptHome}/daily-backup/run.sh"

    # Hourly zapping at 13 mins past every hour
    jobs[2]="13 * * * * ${ScriptHome}/utility/remove-tempgenerated.sh"

    # Hourly backup of Cyclescape
    jobs[3]="19 * * * * ${ScriptHome}/backup-deployment/cyclescapeDownloadAndRotateHourly.sh"

    # Daily download of Cyclestreets Dev - subversion repo and trac
    jobs[4]="49 7 * * * ${ScriptHome}/daily-backup/csDevDownloadAndRotateDaily.sh"

    # Daily rotate of Cyclescape
    jobs[5]="26 8 * * * ${ScriptHome}/backup-deployment/cyclescapeRotateDaily.sh"

    # Daily rotate of Cyclestreets
    jobs[6]="39 8 * * * ${ScriptHome}/daily-backup/cyclestreetsRotateDaily.sh"

    # Daily update of code base and clearout of old routing files at 9:49am
    jobs[7]="49 9 * * * ${ScriptHome}/utility/backup-maintenance.sh"

    # Weekly rotation of backups
    jobs[8]="50 10 * * 7 ${ScriptHome}/daily-backup/cyclestreetsRotateWeekly.sh"

    for job in "${jobs[@]}"
    do
	# Check the format which should be 5 timings followed by the script each separated by a single space
	[[ ! $job =~ ^([^' ']+' '){5}([^' ']+)$ ]] && echo "# Crontab intallation incorrect job format (m h dom mon dow usercommand) for: $job" && exit 1

	# Fish out the command which is the last component of the match
	command="${BASH_REMATCH[2]}"

	# Install/update the job
	# frgrep -v .. <(${} crontab -l) filters out any previous occurrences from the user's crontab listing
	# The echo adds the new job and the cat | pipes it to set the user's updated crontab
	cat <(fgrep -i -v "$command" <(${asCS} crontab -l)) <(echo "$job") | ${asCS} crontab -

	# Installed
	echo "#	Cron: $job"
    done

else

    # Remove the cron job here
    echo "#	Remove any installed cron jobs"
    ${asCS} crontab -r

fi

# Confirm end of script
echo -e "#	All now deployed $(date)"

# End of file
