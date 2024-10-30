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
rm -f collisions.csv casualties.csv vehicles.csv
rm -f collisions.zip




# ------------------------------------------------------------------------------------------------------------------------
# DOWNLOAD DATA FRESHLY
# ------------------------------------------------------------------------------------------------------------------------


# Create a fresh downloads directory, to deal with any updates
today=`date +%Y-%m-%d`
dataDirectory=rawdata-asof-$today
mkdir -p $dataDirectory
cd $dataDirectory

# 1979 - 2023 (released 27th September 2024)
wget -O collisions.csv https://data.dft.gov.uk/road-accidents-safety-data/dft-road-casualty-statistics-collision-1979-latest-published-year.csv
wget -O casualties.csv https://data.dft.gov.uk/road-accidents-safety-data/dft-road-casualty-statistics-casualty-1979-latest-published-year.csv
wget -O vehicles.csv https://data.dft.gov.uk/road-accidents-safety-data/dft-road-casualty-statistics-vehicle-1979-latest-published-year.csv

# Codings - obtain, convert to CSV, and amend headings
wget -O codings.xlsx https://data.dft.gov.uk/road-accidents-safety-data/dft-road-casualty-statistics-road-safety-open-dataset-data-guide-2023.xlsx
ssconvert codings.xlsx codings.csv
rm codings.xlsx
sed -i.bak 1d codings.csv
sed -i.bak '1s/^/sheet,field,code,label,note\n/' codings.csv
rm codings.csv.bak


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
wc -l collisions.csv
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
zip collisions.zip collisions.csv casualties.csv vehicles.csv codings.csv

echo "Please now SFTP the file to the server, e.g. to https://www.cyclestreets.net/collisions.zip temporarily, then use that URL in the import UI. That takes around 30-40 minutes to run."



# ------------------------------------------------------------------------------------------------------------------------
# CLEAN UP
# ------------------------------------------------------------------------------------------------------------------------

rm -f collisions.csv casualties.csv vehicles.csv codings.csv

