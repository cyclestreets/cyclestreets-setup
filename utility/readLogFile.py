# This file has to:
# Open a log file
# Go to the last line
# Work back finding 200 occurrences of calls to /api/journey.json
# Make an average of the last integers at the end of the line
# Convert to seconds

import subprocess

print "#\tStarting"

# Log file
logfile = "/websites/www/logs/api-veebee-access.log"

# Number of lines
lines = 4

# Get the last few lines of the log file
p = subprocess.Popen(["tail", "-n" + str(lines), logfile], stdout=subprocess.PIPE)

# Read the data
line = p.stdout.readline()

while line:
    print line
    line = p.stdout.readline()
    
print "#\tStopping"
