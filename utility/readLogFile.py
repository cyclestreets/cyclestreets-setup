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
from datetime import datetime

class readLogFile ():
    """
    Functions for reading a log file
    """
    
    def __init__(self, logfile):

        # Trace
        print "#\tStarting"

        # Log file
        self.logfile = logfile

        # Number of lines of the log file to scan
        # !! On veebee a value of 200 was resulting in tail giving the first lines even though there were many more lines than that
        self.lines = 200

        # Minimum number of input data lines
        # If less than this amount of data is available all results are zero.
        self.minimumDataLines = 10	#int(math.ceil(lines/3.0))

        # Api call pattern
        self.apiCall = 'api/journey.'

        # Current time
        self.now = datetime.now()

    def checkLastEntryIsRecent (self):
        """
        Checks that the last entry in the log has occurred in the last five minutes.
        """
        # Get the last few lines of the log file
        p = subprocess.Popen(["tail", "--lines=1", self.logfile], stdout=subprocess.PIPE)

        # Get the first line
        line = p.stdout.readline()

        # Close
        p.kill()

        # Result
        return self.recentlyLoggedLine(line)
        
    # Helper function
    def recentlyLoggedLine (self, line):
        """
        Determines if the line was logged within the last five minutes.
        """
        # Extract the date time component
        loggedTime = re.compile(r".*\[\s?([^\s]+)\s([^\]]+)\]").search(line)
        if not loggedTime:
            return False

        # Bind
        loggedDateTime  = loggedTime.group(1)

        # In future examine the time zone offset
        if False:
            loggedUTCoffset = loggedTime.group(2)
            utcOffset = re.compile(r"([+-])([0-9]{2})([0-9]{2})").search(loggedUTCoffset)
            utcOffsetSeconds = 1 if utcOffset.group(1) == '+' else -1
            utcOffsetSeconds = utcOffsetSeconds * (int(utcOffset.group(2)) * 3600) 
            utcOffsetSeconds += int(utcOffset.group(3)) * 60

        # Parse into an object
        datetime_object = datetime.strptime(loggedDateTime, '%d/%b/%Y:%H:%M:%S')
        if not datetime_object:
            return False

        # Difference
        age = self.now - datetime_object

        # Trace
        #print age

        # Result
        return age.seconds <= 300


# logfile = "/websites/www/logs/veebee-access.log"
# Read args supplied to script
rlf = readLogFile(sys.argv[1])
print rlf.logfile
print rlf.checkLastEntryIsRecent()
import sys
sys.exit()


# Get the last few lines of the log file
p = subprocess.Popen(["tail", "--lines=" + str(lines), logfile], stdout=subprocess.PIPE)


# Trace
# print now



# Number of matching lines
count = 0

# Total time
microSeconds = 0

# Array of response times
lingerTimes = []

def considerLine (line):
    """
    Determines whether to include the line in the analysis.
    It needs to:
    1. Contain the api call
    2. Have been logged within the last five minutes
    """
    if apiCall not in line:
        return False
    return recentlyLoggedLine(line)

# Get the first line
line = p.stdout.readline()

# Scan
while line:

    # Trace
    print line
    print 'yes' if apiCall in line else 'no'
    print recentlyLoggedLine (line)

    # Check if the line contains call to the journey api
    if considerLine(line):
        print "#\tConsidering ... " + str(count)
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
print "#\tStopping, counted: " + str(count) + " time: " + str(averageLingerMs) + "ms, " + str(microSeconds) + " microseconds."

#import sys
#sys.exit()


# End of file
