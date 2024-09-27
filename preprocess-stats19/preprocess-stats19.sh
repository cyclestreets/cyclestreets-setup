#!/usr/bin/env bash


# This script takes about 5-10 minutes to run.


# To compare CSV headers, use e.g.
# diff <(head -n1 Veh.csv | tr "|" "\n") <( head -n1 V.csv | tr "|" "\n")



# ------------------------------------------------------------------------------------------------------------------------
# START SCRIPT
# ------------------------------------------------------------------------------------------------------------------------


# End if any error
set -e


# Remove any files from a previous run
rm -f accidents.csv casualties.csv vehicles.csv
rm -f collisions.zip


# Ensure there is a codings file; this should be exported from last year
if [ ! -f codings.csv ]; then
	echo 'There is no codings file'
	exit
fi




# ------------------------------------------------------------------------------------------------------------------------
# DOWNLOAD DATA FRESHLY
# ------------------------------------------------------------------------------------------------------------------------


# Create a fresh downloads directory, to deal with any updates
today=`date +%Y-%m-%d`
dataDirectory=rawdata-asof-$today
mkdir -p $dataDirectory


# 1979 - 2023 (released 27th September 2024)
wget -P $dataDirectory -O accidents.csv https://data.dft.gov.uk/road-accidents-safety-data/dft-road-casualty-statistics-collision-1979-latest-published-year.csv
wget -P $dataDirectory -O casualties.csv https://data.dft.gov.uk/road-accidents-safety-data/dft-road-casualty-statistics-casualty-1979-latest-published-year.csv
wget -P $dataDirectory -O vehicles.csv https://data.dft.gov.uk/road-accidents-safety-data/dft-road-casualty-statistics-vehicle-1979-latest-published-year.csv


# ------------------------------------------------------------------------------------------------------------------------
# FIX TECHNICAL FORMAT ISSUES
# ------------------------------------------------------------------------------------------------------------------------

# Remove BOM at start of files
perl -e 's/^\xef\xbb\xbf//;' *.csv

# Convert \r\n to \n
dos2unix *.csv



# ------------------------------------------------------------------------------------------------------------------------
# COMBINE FILES and SHOW COUNTS
# ------------------------------------------------------------------------------------------------------------------------

# Show counts of original files
wc -l accidents.csv
echo -e "\n"
wc -l casualties.csv
echo -e "\n"
wc -l vehicles.csv
echo -e "\n"
wc -l codings.csv
echo -e "\n"



# ------------------------------------------------------------------------------------------------------------------------
# ZIP AS SINGLE DISTRIBUTION
# ------------------------------------------------------------------------------------------------------------------------

# Zip files into a single distribution
zip collisions.zip accidents.csv casualties.csv vehicles.csv codings.csv

echo "Please now SFTP the file to the server, e.g. to https://www.cyclestreets.net/collisions.zip temporarily, then use that URL in the import UI. That takes around 30-40 minutes to run."



# ------------------------------------------------------------------------------------------------------------------------
# CLEAN UP
# ------------------------------------------------------------------------------------------------------------------------

rm -f accidents.csv casualties.csv vehicles.csv

