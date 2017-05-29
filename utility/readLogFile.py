# A helper script for generating journey planner performance data for munin.
#
# This script fetches the last few lines of an Apache access log that contains
# server response times in microseconds at the end of each line.
# It filters for the journey calls and calculates the average response rate in milliseconds.

# Dependencies
import subprocess, re

# Trace
# print "#\tStarting"

# Log file
logfile = "/websites/www/logs/veebee-access.log"

# Number of lines
lines = 200

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

# Scan
while line:

    # Trace
    #print line

    # Check if the line contains call to the journey api
    if apiCall in line:

        count += 1

        # Find the number at the end of the line
        match = re.match('.*?([0-9]+)$', line)
        if match:
            microSeconds += int(match.group(1))

    # Read next line
    line = p.stdout.readline()


# Time in millisconds
milliSeconds = 0

# Calculate the average
if count > 0:
    # float()  ensures the / avoids truncating
    milliSeconds = round(float(microSeconds) / (count * 1000))

# Result
print int(milliSeconds)

# Trace
#print "#\tStopping, counted: " + str(count) + " time: " + str(milliSeconds) + "ms, " + str(microSeconds) + " microseconds."

# End of file
