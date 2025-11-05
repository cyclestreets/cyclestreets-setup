#!/usr/bin/env python3
#
#	CycleStreets monitoring data for munin
#
# SYNOPSIS
# 	munin-run journeylinger [config]
#
# DESCRIPTION
# 	If the optional argument config is supplied (as the plain string: config), this script
#	returns a summary of the parameters provided by this munin plugin.
#	Without that argument the values of those parameters are returned.
#
# Dependencies
#	munin-node
#
# Create a link to this script from the munin configuration:
# sudo ln -s /opt/cyclestreets-setup/live-deployment/munin-journeylinger.py /etc/munin/plugins/journeylinger
#
# Then restart munin node
# sudo systemctl restart munin-node
#
# Example calls
# sudo munin-run journeylinger config
# sudo munin-run journeylinger
#
# Remove
# sudo rm /etc/munin/plugins/journeylinger

import urllib.request, urllib.parse, urllib.error, json, sys

# Placeholders
journeysLog = "%journeysLog"
scriptHome = "%ScriptHome"

# Import module as the function name
# Make the utility available to the module search
sys.path.append(scriptHome + '/utility/')
from accessLogLingerStats import accessLogLingerStats	# Import module as the function name

def print_config():
    print("graph_title CycleStreets Journey Linger")
    # Category groups must be lower cased (not explicit in munin documentation) so that warning/critical indicators appear on overview page
    print("graph_category cyclestreets")
    print("graph_vlabel Milliseconds")
    print("graph_info Performance of the CycleStreets journey API according to the apache access log.")

    # Use an upper limit of 4 seconds so making it easier to compare with across servers
    print("graph_args -l 0 --upper-limit 4000 --rigid")

    # Average linger
    print("journey_linger.label Average ms")
    print("journey_linger.info The time in milliseconds taken to respond to a CycleStreets journey API call according to the apache access log.")
    print("journey_linger.colour CCAAEE")

    # Linger of slowest
    print("journey_slowest.label Slowest ms")
    print("journey_slowest.info The longest time to plan a journey.")
    print("journey_slowest.colour EECCCC")
    print("journey_slowest.line 3000:CCCCCC:3 second timeout")
    
    # Linger at 90th percentile
    print("journey_top90linger.label 90th percentile ms")
    print("journey_top90linger.info Linger at the 90th percentile when ordered by time ascending.")
    print("journey_top90linger.colour 3366DD")
    print("journey_top90linger.line 700:DDBB44:700ms threshold")
    print("journey_top90linger.warning 0:600")
    print("journey_top90linger.critical 0:700")

def getData():

	# Read args supplied to script
	alls = accessLogLingerStats(journeysLog)

	# Get the stats
	alls.generateStatistics()

## Main

# Parse arguments
if len(sys.argv) > 1:
    if sys.argv[1] == "config":
        print_config()
        sys.exit(0)
else:
	getData();

# End of file
