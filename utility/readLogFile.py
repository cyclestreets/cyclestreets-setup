# A helper script for generating journey planner API performance data for munin.
#
# This script fetches the last few lines of an Apache access log that contains
# server response times in microseconds at the end of each line.
# It filters for the journey API calls and calculates several statistics
# that characterize how long the server has been taking to respond - ie how long
# the caller must linger for a result.
#
# Synopsis
#	readLogFile.py logFile
#
# Result
#	Serveral results, in milisconds, are generated each on a new line:
#	* The slowest response time
#	* Average response time
#	* Response time at the 90th percentile when ordered by ascending time
#
# Example
# user@veebee:/opt/cyclestreets-setup$
# python utility/readLogFile.py /websites/www/logs/veebee-access.log
# journey_linger.value 22
# journey_top90linger.value 39
# journey_slowest.value 39

# Dependencies
import subprocess, re, sys, math

# Trace
# print "#\tStarting"

# Log file
# logfile = "/websites/www/logs/veebee-access.log"

# Read args supplied to script
logfile = sys.argv[1]


# Number of lines of the log file to scan
lines = 200

# Minimum number of input data lines
# If less than this amount of data is available all results are zero.
minimumDataLines = 10	#int(math.ceil(lines/3.0))

# Api call pattern
apiCall = 'api/journey.json'

# Get the last few lines of the log file
p = subprocess.Popen(["tail", "-n" + str(lines), logfile], stdout=subprocess.PIPE)

# Read the data
line = p.stdout.readline()

# Number of matching lines
count = 0

# Total time
microSeconds = 0

# Array of response times
lingerTimes = []

# Scan
while line:

    # Trace
    #print line

    # Check if the line contains call to the journey api
    if apiCall in line:

        # Find the number at the end of the line after a solidus
        match = re.match('.+?/([0-9]+)$', line)
        if match:
	    count += 1
            microSeconds += int(match.group(1))
            lingerTimes.append(int(match.group(1)))

    # Read next line
    line = p.stdout.readline()


# Time in millisconds
averageLingerMs = 0
top90percentLingerMs = 0
slowestLingerMs = 0

# When there is sufficient input data
if count >= minimumDataLines:

    # Calculate the average
    # float()  ensures the / avoids truncating
    averageLingerMs = round(float(microSeconds) / (count * 1000))

    # 90% target
    # Sort the list ascending times
    ascending = sorted(lingerTimes)

    # Consider the first 90%
    top90startIndex = int(math.ceil(0.9 * len(lingerTimes)))
    top90percentLingerMs = round(float(ascending[top90startIndex]) / 1000)

    # Slowest
    slowestLingerMs = math.ceil(float(ascending[-1]) / 1000)

    # Trace
    #print "#\tTop 90% index: " + str(top90startIndex) + ", time: " + str(top90percentLingerMs) + " ms"


# Results
print 'journey_slowest.value {:d}'.format(int(slowestLingerMs))
print 'journey_linger.value {:d}'.format(int(averageLingerMs))
print 'journey_top90linger.value {:d}'.format(int(top90percentLingerMs))

# Trace
#print "#\tStopping, counted: " + str(count) + " time: " + str(averageLingerMs) + "ms, " + str(microSeconds) + " microseconds."


# End of file
