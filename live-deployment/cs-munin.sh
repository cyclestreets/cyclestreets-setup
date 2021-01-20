#!/bin/bash
#	Generates CycleStreets data for munin
#
# SYNOPSIS
# 	munin-run cyclestreets [config]
#
# DESCRIPTION
# 	If the optional argument config is supplied (as the plain string: config), this script
#	returns a summary of the parameters provided by this munin plugin.
#	Without that argument the values of those parameters are returned.
#
# Configure
# Install this package on the relevant server:
# apt-get -y install munin-node
#
# Create a link to this script from the munin configuration:
# sudo ln -s /opt/cyclestreets-setup/live-deployment/cs-munin.sh /etc/munin/plugins/cyclestreets
#
# Then restart munin node
# sudo systemctl restart munin-node
#
# Example calls
# sudo munin-run cyclestreets config
# sudo munin-run cyclestreets
#
# Remove
# sudo rm /etc/munin/plugins/cyclestreets
#
# See also
# https://wiki.cyclestreets.net/ServerMonitoring

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
    echo "#	The config file, ${configFile}, does not exist or is not executable - copy your own based on the ${configFile}.template file."
    exit 1
fi

# Load the credentials
. ${configFile}


## Main body of script

## Public functions as called by munin

# Outputs the config of this plugin
output_config() {
    echo "graph_title CycleStreets Usage"
    echo "graph_category CycleStreets"
    echo "itineraries.label Itineraries per 5 mins"
    echo "journeys.label Journeys per 5 mins"
    echo "failedJourneys.label Failed journeys per 5 mins"
    echo "failedJourneys.warning 1"
    echo "failedJourneys.critical 200"
    echo "errors.label Errors per 5 mins"
    echo "errors.warning 1"
    echo "errors.critical 5"
}

# Outputs the statistics
output_values() {
    printf "itineraries.value %d\n" $(number_of_itineraries)
    printf "journeys.value %d\n" $(number_of_journeys)
    printf "failedJourneys.value %d\n" $(number_of_failed_journeys)
    printf "errors.value %d\n" $(number_of_errors)
}

# Explain arguments to this script
output_usage() {
    printf >&2 "%s - CycleStreets graphs\n" ${0##*/}
    printf >&2 "Usage: %s [config]\n" ${0##*/}
}

## Internal functions that provide the statistics

# Useful binding
# The defaults-extra-file is a positional argument which must come first.
superMysql="mysql --defaults-extra-file=${mySuperCredFile} -hlocalhost"

# Number of itineraries in a five minute period
number_of_itineraries() {
    #${superMysql} cyclestreets -sNe "select countItinerariesLastFiveMinutes()";
    python ${ScriptHome}/utility/readjson.py http://${apiHostname} ${testsApiKey} countItinerariesLastFiveMinutes
}

# Number of journeys in a five minute period
number_of_journeys() {
    #${superMysql} cyclestreets -sNe "select countJourneysLastFiveMinutes()";
    python ${ScriptHome}/utility/readjson.py http://${apiHostname} ${testsApiKey} countJourneysLastFiveMinutes
}

# Number of journeys in a five minute period
number_of_failed_journeys() {
    #${superMysql} cyclestreets -sNe "select countFailedJourneysLastFiveMinutes()";
    python ${ScriptHome}/utility/readjson.py http://${apiHostname} ${testsApiKey} countFailedJourneysLastFiveMinutes
}

# Number of errors in a five minute period
number_of_errors() {
    #${superMysql} cyclestreets -sNe "select countErrorsLastFiveMinutes()";
    python ${ScriptHome}/utility/readjson.py http://${apiHostname} ${testsApiKey} countErrorsLastFiveMinutes
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
