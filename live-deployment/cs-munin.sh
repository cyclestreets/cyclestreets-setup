#!/bin/bash
#	Generates CycleStreets data for munin
#
# SYNOPSIS
# 	munin-run cyclestreets [config]
#
# DESCRIPTION
# 	If the optional argument config is supplied (as the plain string: config), this script returns a summary of the parameters provided by this munin plugin.
#	Without that argument the values of those parameters are returned.
#
# Configure
# Install this package on the relevant server:
# apt-get install munin-node
#
# Create a link to this script from the munin configuration:
# sudo ln -s /opt/cyclestreets-setup/live-deployment/cs-munin.sh /etc/munin/plugins/cyclestreets
#
# Then restart munin
# sudo /etc/init.d/munin-node restart
#
# Example calls
# sudo munin-run cyclestreets config
# sudo munin-run cyclestreets
#
# Remove
# sudo rm /etc/munin/plugins/cyclestreets
#
# See also
# https://dev.cyclestreets.net/wiki/ServerMonitoring

### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The multi-line method of geting the script directory is needed because this script is likely symlinked
SOURCE="${BASH_SOURCE[0]}"
DIR="$( dirname "$SOURCE" )"
while [ -h "$SOURCE" ]
do 
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
  DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

# Use this to remove the ../
ScriptHome=$(readlink -f "${DIR}/..")

# Name of the credentials file
configFile=${ScriptHome}/.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x ${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file."
    exit 1
fi

# Load the credentials
. ${configFile}


## Main body of script

## Public functions as called by munin

# Outputs the config of this plugin
output_config() {
    echo "graph_title CycleStreets usage"
    echo "graph_category CycleStreets"
    echo "itineraries.label Itineraries per 5 mins"
    echo "failedItineraries.label Failed itineraries per 5 mins"
    echo "errors.label Errors per 5 mins"
}

# Outputs the statistics
output_values() {
    printf "itineraries.value %d\n" $(number_of_itineraries)
    printf "failedItineraries.value %d\n" $(number_of_failed_itineraries)
    printf "errors.value %d\n" $(number_of_errors)
}

# Explain arguments to this script
output_usage() {
    printf >&2 "%s - CycleStreets itineraries graphs\n" ${0##*/}
    printf >&2 "Usage: %s [config]\n" ${0##*/}
}


## Internal functions that provide the statistics

# Number of itineraries in a five minute period
# Avoids the latest minute's worth of data as that would include unfinished route calculations.
number_of_itineraries() {
    mysql --defaults-extra-file=${mycnfFile} cyclestreets -sNe "select count(distinct itineraryId) count from map_journey where datetime > now() - interval 6 minute and datetime < now() - interval 1 minute";
}

# Number of itineraries in a five minute period
number_of_failed_itineraries() {
    mysql --defaults-extra-file=${mycnfFile} cyclestreets -sNe "select count(distinct itineraryId) count from map_journey where length = 0 and datetime > now() - interval 6 minute and datetime < now() - interval 1 minute";
}

# Number of errors in a five minute period
number_of_errors() {
    mysql --defaults-extra-file=${mycnfFile} cyclestreets -sNe "select count(*) count from map_error where datetime > now() - interval 6 minute and datetime < now() - interval 1 minute";
}


# Run the above functions, according to the arguments given to this script

case $# in
    0)
        output_values
        ;;
    1)
        case $1 in
            config)
                output_config
                ;;
            *)
                output_usage
                exit 1
                ;;
        esac
        ;;
    *)
        output_usage
        exit 1
        ;;
esac

# End of file
