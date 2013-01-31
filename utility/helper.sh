#!/bin/bash

## Helper functions

#	Install cron jobs
#	The first argument should be an array of cron jobs
installCronJobs ()
{
    # http://stackoverflow.com/questions/1063347/passing-arrays-as-parameters-in-bash
    # Uses the ${!...} notation to indirectly refer to the value of $1, the first argument.
    declare -a jobs=("${!1}")

    # Trace - Indicate number of jobs
    echo "#	Installing ${#jobs[@]} cron jobs"

    for job in "${jobs[@]}"
    do

	# Check the format which should be 5 timings followed by the script each separated by a single space
	[[ ! $job =~ ^([^' ']+' '){5}(.+)$ ]] && echo "# Crontab intallation incorrect job format (m h dom mon dow usercommand) for: $job" && exit 1

	# Fish out the command which is the last component of the match
	command="${BASH_REMATCH[2]}"

	# Install/update the job
	# frgrep -v .. <(${} crontab -l) filters out any previous occurrences from the user's crontab listing
	# The echo adds the new job and the cat | pipes it to set the user's updated crontab
	cat <(fgrep -i -v "$command" <(${asCS} crontab -l)) <(echo "$job") | ${asCS} crontab -

	# Trace - Indicate number of jobs
	echo "#	Installed ${job}"
    done
}

# End of file
