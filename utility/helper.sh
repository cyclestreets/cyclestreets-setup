#!/bin/bash
#
# SYNOPSIS
#	installCronJob user job
#
# DESCRIPTION
#	The first argument identifies which user's crontab
#	The second argument names an array of cron jobs, ie. use: jobs[@] rather than $jobs
installCronJob ()
{
    # Shortcut for running commands as the suggested user
    asUser="sudo -u $1"

    # Useful binding
    job=$2

    # Check the format which should be 5 timings followed by the script each separated by a single space
    [[ ! $job =~ ^([^' ']+' '){5}(.+)$ ]] && echo "# Crontab intallation incorrect job format (m h dom mon dow usercommand) for: $job" && exit 1

    # Fish out the command which is the last component of the match
    command="${BASH_REMATCH[2]}"

    # Install/update the job
    # frgrep -v .. <(${} crontab -l) filters out any previous occurrences from the user's crontab listing
    # The echo adds the new job and the cat | pipes it to set the user's updated crontab
    cat <(fgrep -i -v "$command" <(${asUser} crontab -l)) <(echo "$job") | ${asUser} crontab -

    # Report installed job
    echo "#	Installed ${job}"
}

# End of file
