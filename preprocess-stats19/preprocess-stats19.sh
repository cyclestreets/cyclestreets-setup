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
rm -f *.csv
rm -f collisions.zip




# ------------------------------------------------------------------------------------------------------------------------
# DOWNLOAD DATA FRESHLY
# ------------------------------------------------------------------------------------------------------------------------


# Create a fresh downloads directory, to deal with any updates
today=`date +%Y-%m-%d`
dataDirectory=rawdata-asof-$today
mkdir -p $dataDirectory


# 1979 - 2020 (released 16 October 2021)
wget -P $dataDirectory -O accidents.csv https://data.dft.gov.uk/road-accidents-safety-data/dft-road-casualty-statistics-accident-1979-2020.csv
wget -P $dataDirectory -O casualties.csv https://data.dft.gov.uk/road-accidents-safety-data/dft-road-casualty-statistics-casualty-1979-2020.csv
wget -P $dataDirectory -O vehicles.csv https://data.dft.gov.uk/road-accidents-safety-data/dft-road-casualty-statistics-vehicle-1979-2020.csv


# ------------------------------------------------------------------------------------------------------------------------
# DATA FIXES
# ------------------------------------------------------------------------------------------------------------------------


# Fix missing NULLs that cause "ERROR 1138 (22004) at line 1249: Invalid use of NULL value"
sed -i.bak 's/20171341E0023,437522,431960,NULL,NULL/20171341E0023,437522,431960,-1.432035,53.782621/' accidents.csv
sed -i.bak 's/20171342E0246,422914,433585,NULL,NULL/20171342E0246,422914,433585,-1.653605,53.798070/' accidents.csv
sed -i.bak 's/20171343E0199,434011,421718,NULL,NULL/20171343E0199,434011,421718,-1.486440,53.690809/' accidents.csv
sed -i.bak 's/20171343E0213,442910,430929,NULL,NULL/20171343E0213,442910,430929,-1.350414,53.772940/' accidents.csv
sed -i.bak 's/20171343E0234,433853,435844,NULL,NULL/20171343E0234,433853,435844,-1.487289,53.817779/' accidents.csv
sed -i.bak 's/20171343E0303,434139,417940,NULL,NULL/20171343E0303,434139,417940,-1.484915,53.656845/' accidents.csv
sed -i.bak 's/20171345E0146,419511,418871,NULL,NULL/20171345E0146,419511,418871,-1.706190,53.665960/' accidents.csv
sed -i.bak 's/20171346E0216,423418,437624,NULL,NULL/20171346E0216,423418,437624,-1.645647,53.834350/' accidents.csv
sed -i.bak 's/20171349E0197,439803,434169,NULL,NULL/20171349E0197,439803,434169,-1.397136,53.802305/' accidents.csv
sed -i.bak 's/20171349E0262,417781,426597,NULL,NULL/20171349E0262,417781,426597,-1.731932,53.735462/' accidents.csv


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



# ------------------------------------------------------------------------------------------------------------------------
# ZIP AS SINGLE DISTRIBUTION
# ------------------------------------------------------------------------------------------------------------------------

# Zip files into a single distribution
zip collisions-to$year.zip accidents.csv casualties.csv vehicles.csv

echo "Please now SFTP the file to the server, e.g. to https://www.cyclestreets.net/collisions-to$year.zip temporarily, then use that URL in the import UI. That takes around 30-40 minutes to run."



# ------------------------------------------------------------------------------------------------------------------------
# CLEAN UP
# ------------------------------------------------------------------------------------------------------------------------

rm *.csv

