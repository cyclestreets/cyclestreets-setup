#!/usr/bin/env python3
#
#	CycleStreets monitoring data for munin rate of Photomap changes
#
# SYNOPSIS
# 	munin-run photomap-rate [config]
#
# DESCRIPTION
# 	If the optional argument config is supplied (as the plain string: config), this script
#	returns a summary of the parameters provided by this munin plugin.
#	Without that argument the values of those parameters are returned.
#
# Create a link to this script from the munin configuration:
# sudo ln -s /opt/cyclestreets-setup/live-deployment/munin-photomap-rate.py /etc/munin/plugins/photomap-rate
#
# Then restart munin node
# sudo systemctl restart munin-node
#
# Example calls
# sudo munin-run photomap-rate config
# sudo munin-run photomap-rate

import urllib.request, urllib.parse, urllib.error, json, sys

# Placeholders
apiV2Url = "%apiV2Url"
apiKey = "%apiKey"

def print_config():
	print("graph_title CycleStreets Photomap Rate")
	print("graph_vlabel Count on the day")
	# Category groups must be lower cased (not explicit in munin documentation) so that warning/critical indicators appear on overview page
	print("graph_category cyclestreets")
	print("locationshangedToday.label Number changed")

def getData():
	# Needs server and api key as config
	url = apiV2Url + "status?key=" + apiKey + "&fields=usage"
	response = urllib.request.urlopen(url)
	return json.loads(response.read())

## Main

# Parse arguments
if len(sys.argv) > 1:
    if sys.argv[1] == "config":
        print_config()
        sys.exit(0)
else:
	data = getData();
	print("locationshangedToday.value {}".format(data["usage"]["getTotalModifiedLocationsToday"]))

# End of file
