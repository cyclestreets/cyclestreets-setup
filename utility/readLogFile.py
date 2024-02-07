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
# user@veebee:$
# python utility/readLogFile.py /websites/www/logs/veebee-access.log
# journey_linger.value 22
# journey_top90linger.value 39
# journey_slowest.value 39
#
#
# The relevant log file needs to include timings at the end of the line.
# That can be done in the virtual host CustomLog or by redfining these formats in the general config using the LogFormat directive.
# Include time (%T) and microtime (%D) in logs; see: http://blog.keul.it/2011/10/debugging-slow-site-using-apache.html
# LogFormat "%h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\" %T/%D" combined
# LogFormat "%v:%p %h %l %u %t \"%r\" %>s %O \"%{Referer}i\" \"%{User-Agent}i\" %T/%D" vhost_combined

# Dependencies
import subprocess, re, sys, math
from datetime import datetime

class readLogFile ():
    """
    Functions for reading a log file
    """
    
    def __init__(self, logfile):

        # Trace
        # print ("#\tStarting")

        # Initialize these statistics as time in millisconds
        self.averageLingerMs = 0
        self.top90percentLingerMs = 0
        self.slowestLingerMs = 0

        # Log file
        self.logfile = logfile

        # Number of lines of the log file to scan
        self.numberOfLines = 1000

        # Minimum number of input data lines
        # If less than this amount of data is available all results are zero.
        self.minimumDataLines = 10

        # Api call pattern
        # v1
        # self.apiCall = 'api/journey.'
        # v2
        # self.apiCall = 'v2/journey.'
        # Both
        self.apiCall = '/journey.'

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

        # Convert from bytes to str
        line = line.decode('utf8')

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
        # print (age.seconds)

        # Result
        return age.seconds <= 300


    # Helper functions
    def printResults (self):
        """
        Print statistics
        """
        print('journey_slowest.value {:d}'.format(int(self.slowestLingerMs)))
        print('journey_linger.value {:d}'.format(int(self.averageLingerMs)))
        print('journey_top90linger.value {:d}'.format(int(self.top90percentLingerMs)))

    def considerLine (self, line):
        """
        Determines whether to include the line in the analysis.
        It needs to:
        1. Contain the api call
        2. Have been logged within the last five minutes
        """
        if self.apiCall not in line:
            return False
        return self.recentlyLoggedLine(line)

    
    def generateStatistics (self):
        """
        Main procedure for reading the log and getting the stats.
        """
        # If the log file hasn't been updated in the last five minutes
        if not self.checkLastEntryIsRecent():

            # Trace
            # print ("#\tLog file is stale: " + str(self.logfile))

            # They will all be zero
            self.printResults()

            # Abandon
            return

        # Scan the file
        self.scan()
        
        # Print results
        self.printResults()


    def scan (self):
        """
        Scan the log file.
        """
        # Trace
        # print ("#\tScanning log file: {}, API: {}".format(str(self.logfile), self.apiCall))
        
        # Get the last few lines of the log file
        p = subprocess.Popen(["tail", "--lines=" + str(self.numberOfLines), self.logfile], stdout=subprocess.PIPE)

        # Get the first line, arrives as bytes
        line = p.stdout.readline()

        # Count matching lines
        count = 0

        # Total time
        microSeconds = 0

        # Array of response times
        lingerTimes = []

        # Scan
        while line:

            # Convert from bytes to str
            line = line.decode('utf8')

            # Check if the line contains call to the journey api
            if self.considerLine(line):

                # Trace
                # print ("#\tConsidering ... " + str(count))
                
                # Find the number at the end of the line after a solidus
                match = re.match('.+?/([0-9]+)$', line)
                if match:
                    count += 1
                    microSeconds += int(match.group(1))
                    lingerTimes.append(int(match.group(1)))

            # Read next line
            line = p.stdout.readline()

        # Insufficient input data?
        if count < self.minimumDataLines:
            # Trace
            # print ("#\tStopping, counted: " + str(count))
            return

        # Calculate the average
        # float()  ensures the / avoids truncating
        self.averageLingerMs = round(float(microSeconds) / (count * 1000))

        # 90% target
        # Sort the list ascending times
        ascending = sorted(lingerTimes)

        # Consider the first 90%
        top90startIndex = int(math.ceil(0.9 * len(lingerTimes)))
        self.top90percentLingerMs = math.ceil(float(ascending[top90startIndex]) / 1000)

        # Slowest
        self.slowestLingerMs = math.ceil(float(ascending[-1]) / 1000)

        # Trace
        # print ("#\tTop 90% index: " + str(top90startIndex) + ", time: " + str(self.top90percentLingerMs) + " ms")

        # Trace
        # print ("#\tStopping, counted: " + str(count) + " time: " + str(self.averageLingerMs) + "ms, " + str(microSeconds) + " microseconds.")


# Main
if __name__ == '__main__':

    # logfile = "/websites/www/logs/veebee-access.log"
    # Read args supplied to script
    rlf = readLogFile(sys.argv[1])

    # Get the stats
    rlf.generateStatistics()


#import sys
#sys.exit()

# End of file
