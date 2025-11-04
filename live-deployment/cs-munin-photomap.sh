#!/bin/bash
# This script has ${placeholder} fields that are replaced by an installer script.
#
#
#	Generates CycleStreets data for munin
#
# SYNOPSIS
# 	munin-run photomap [config]
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
# sudo ln -s /opt/cyclestreets-setup/live-deployment/cs-munin-photomap.sh /etc/munin/plugins/photomap
#
# Then restart munin node
# sudo systemctl restart munin-node
#
# Example calls
# sudo munin-run photomap config
# sudo munin-run photomap
#
# Remove
# sudo rm /etc/munin/plugins/photomap
#
# See also
# https://wiki.cyclestreets.net/ServerMonitoring

### CREDENTIALS ###
# These should have already been loaded by an installing script
if [ -z "${ScriptHome}" ]; then
	echo "#	Munin/ Photomap : ScriptHome is one of several placeholders that need replacing with values by the installer."
	exit 1
fi

## Main body of script

## Public functions as called by munin

# Outputs the config of this plugin
output_config() {
	echo "graph_title CycleStreets Photomap"
	echo "graph_vlabel Count"
	echo "graph_category cyclestreets"	# Category groups are all lower cased (not explicit in munin documentation), so do that here so that warning/critical css classes appear on overview page
	echo "photos.label Total photos"
}

# Outputs the statistics
output_values() {
	printf "photos.value %d\n" $(number_of_photos)
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

# Number of photos in a five minute period
number_of_photos() {
	#${superMysql} cyclestreets -sNe "select getTotalPhotos()";
	python3 ${ScriptHome}/utility/readjson.py http${apiHostHttps}://${apiHostname} ${testsApiKey} getTotalPhotos
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
