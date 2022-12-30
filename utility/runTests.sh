#!/bin/bash
# Description
#	Utility to run CycleStreets tests
# Synopsis
#	Expects summaryFile variable to be setup already.

## Switch to main folder
if [ -z "${websitesContentFolder}" ]; then
    websitesContentFolder=/websites/www/content
fi
cd "${websitesContentFolder}"

# Generate Tests Summary message
if [ -z "${summaryFile}" ]; then
    summaryFile=testResults.txt
fi
echo -e "#\tTests Summary" > ${summaryFile}

# Run tests relevant to the new build, appending to summary
echo -e "# $(date)\tStarting nearest point tests" >> ${summaryFile}
php runtests.php "call=nearestpoint" >> ${summaryFile}

echo -e "# $(date)\tStarting journey API 1 tests" >> ${summaryFile}
php runtests.php "call=journey&apiVersion=1" >> ${summaryFile}

echo -e "# $(date)\tStarting journey API 2 tests" >> ${summaryFile}
php runtests.php "call=journey&apiVersion=2" >> ${summaryFile}

# Compare new coverage with when the elevation.values auto tests were created
echo -e "# $(date)\tStarting elevation auto generated tests" >> ${summaryFile}
php runtests.php "call=elevation.values&name=Elevation auto generated test:" >> ${summaryFile}

# Finished
echo -e "# $(date)\tCompleted tests" >> ${summaryFile}

# End of file
