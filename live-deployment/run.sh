#!/bin/bash
# Script to install CycleStreets on Ubuntu
# Tested on 12.10 (View Ubuntu version using 'lsb_release -a')
# This script is idempotent - it can be safely re-run without destroying existing data

echo "#	CycleStreets live deployment $(date)"

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
SCRIPTDIRECTORY=$DIR

# Name of the credentials file
configFile=../.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -e ./${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. ./${configFile}


# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Main body of script

# Install the website
#. ../install-website/run.sh

# Cron jobs
if $installCronJobs ; then

    # Install the cron job here
    echo "#	Install cron jobs"

    # Daily replication every day at 4:04 am
    jobs[1]="4 4 * * * $SCRIPTDIRECTORY/../replicate-data/run.sh"

    # Hourly zapping at 13 mins past every hour
    jobs[2]="13 * * * * $SCRIPTDIRECTORY/../remove-tempgenerated/run.sh"

    # Install routing data at 34 mins past every hour in the small hours
    jobs[3]="34 0,1,2,3,4,5 * * * $SCRIPTDIRECTORY/../install-routing-data/run.sh"

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
