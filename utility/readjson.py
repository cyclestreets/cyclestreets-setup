# A simple way of reading data from json
# This implementation is used to read usage data from the status api.
import urllib, json, sys

# Read args supplied to script
apihostname = sys.argv[1]
apikey = sys.argv[2]
field = sys.argv[3]

# Needs server and api key as config
url = "http://" + apihostname + "/v2/status?key=" + apikey + "&fields=usage"
response = urllib.urlopen(url)
data = json.loads(response.read())
print data["usage"][field]
