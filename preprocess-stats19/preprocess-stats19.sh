#!/usr/bin/env bash


# To compare CSV headers, use e.g.
# diff <(head -n1 Veh.csv | tr "|" "\n") <( head -n1 V.csv | tr "|" "\n")


# End if any error
set -e


# Remove any files from a previous run
rm -f *.csv
rm -f collisions.zip



# Unzip each year, and fix up any specific problems for that year's data


# 2005 - 2014
#
unzip rawdata/Stats19_Data_2005-2014.zip

mv Accidents0514.csv Accidents_2005-2014.csv
mv Casualties0514.csv Casualties_2005-2014.csv
mv Vehicles0514.csv Vehicles_2005-2014.csv

# Accidents_2005-2014.csv
# Accident_Index,Location_Easting_OSGR,Location_Northing_OSGR,Longitude,Latitude,Police_Force,Accident_Severity,Number_of_Vehicles,Number_of_Casualties,Date,Day_of_Week,Time,Local_Authority_(District),Local_Authority_(Highway),1st_Road_Class,1st_Road_Number,Road_Type,Speed_limit,Junction_Detail,Junction_Control,2nd_Road_Class,2nd_Road_Number,Pedestrian_Crossing-Human_Control,Pedestrian_Crossing-Physical_Facilities,Light_Conditions,Weather_Conditions,Road_Surface_Conditions,Special_Conditions_at_Site,Carriageway_Hazards,Urban_or_Rural_Area,Did_Police_Officer_Attend_Scene_of_Accident,LSOA_of_Accident_Location
# Acc2015.csv
# Accident_Index,Location_Easting_OSGR,Location_Northing_OSGR,Longitude,Latitude,Police_Force,Accident_Severity,Number_of_Vehicles,Number_of_Casualties,Date,Day_of_Week,Time,Local_Authority_(District),Local_Authority_(Highway),1st_Road_Class,1st_Road_Number,Road_Type,Speed_limit,Junction_Detail,Junction_Control,2nd_Road_Class,2nd_Road_Number,Pedestrian_Crossing-Human_Control,Pedestrian_Crossing-Physical_Facilities,Light_Conditions,Weather_Conditions,Road_Surface_Conditions,Special_Conditions_at_Site,Carriageway_Hazards,Urban_or_Rural_Area,Did_Police_Officer_Attend_Scene_of_Accident,LSOA_of_Accident_Location

# Vehicles_2015 and later have extra column "Vehicle_IMD_Decile", so this needs to be added to the first CSV
#   Vehicles_2005-2014.csv:
#     Accident_Index,Vehicle_Reference,Vehicle_Type,Towing_and_Articulation,Vehicle_Manoeuvre,Vehicle_Location-Restricted_Lane,Junction_Location,Skidding_and_Overturning,Hit_Object_in_Carriageway,Vehicle_Leaving_Carriageway,Hit_Object_off_Carriageway,1st_Point_of_Impact,Was_Vehicle_Left_Hand_Drive?,Journey_Purpose_of_Driver,Sex_of_Driver,Age_of_Driver,Age_Band_of_Driver,Engine_Capacity_(CC),Propulsion_Code,Age_of_Vehicle,Driver_IMD_Decile,Driver_Home_Area_Type
#   Veh2015.csv:
#     Accident_Index,Vehicle_Reference,Vehicle_Type,Towing_and_Articulation,Vehicle_Manoeuvre,Vehicle_Location-Restricted_Lane,Junction_Location,Skidding_and_Overturning,Hit_Object_in_Carriageway,Vehicle_Leaving_Carriageway,Hit_Object_off_Carriageway,1st_Point_of_Impact,Was_Vehicle_Left_Hand_Drive?,Journey_Purpose_of_Driver,Sex_of_Driver,Age_of_Driver,Age_Band_of_Driver,Engine_Capacity_(CC),Propulsion_Code,Age_of_Vehicle,Driver_IMD_Decile,Driver_Home_Area_Type,Vehicle_IMD_Decile
#perl -pi -e 's/$/,/g' Vehicles_2005-2014.csv
dos2unix Vehicles_2005-2014.csv
awk '$0=$0","' Vehicles_2005-2014.csv > Vehicles_2005-2014_extracolumn.csv
mv Vehicles_2005-2014_extracolumn.csv Vehicles_2005-2014.csv
perl -pi -e 's/Driver_Home_Area_Type,/Driver_Home_Area_Type,Vehicle_IMD_Decile/g' Vehicles_2005-2014.csv

# Ditto Casualties_2015 and later has extra column "Casualty_IMD_Decile"
#   Casualties_2005-2014.csv:
#     Accident_Index,Vehicle_Reference,Casualty_Reference,Casualty_Class,Sex_of_Casualty,Age_of_Casualty,Age_Band_of_Casualty,Casualty_Severity,Pedestrian_Location,Pedestrian_Movement,Car_Passenger,Bus_or_Coach_Passenger,Pedestrian_Road_Maintenance_Worker,Casualty_Type,Casualty_Home_Area_Type
#   Cas2015.csv:
#     Accident_Index,Vehicle_Reference,Casualty_Reference,Casualty_Class,Sex_of_Casualty,Age_of_Casualty,Age_Band_of_Casualty,Casualty_Severity,Pedestrian_Location,Pedestrian_Movement,Car_Passenger,Bus_or_Coach_Passenger,Pedestrian_Road_Maintenance_Worker,Casualty_Type,Casualty_Home_Area_Type,Casualty_IMD_Decile
#perl -pi -e 's/$/,/g' Casualties_2005-2014.csv
dos2unix Casualties_2005-2014.csv
awk '$0=$0","' Casualties_2005-2014.csv > Casualties_2005-2014_extracolumn.csv
mv Casualties_2005-2014_extracolumn.csv Casualties_2005-2014.csv
perl -pi -e 's/Casualty_Home_Area_Type,/Casualty_Home_Area_Type,Casualty_IMD_Decile/g' Casualties_2005-2014.csv


# 2015
#
unzip rawdata/RoadSafetyData_2015.zip
mv Accidents_2015.csv Acc2015.csv
mv Casualties_2015.csv Cas2015.csv
mv Vehicles_2015.csv Veh2015.csv

# Remove the headers
awk 'FNR > 1' Acc2015.csv > Accidents_2015.csv
awk 'FNR > 1' Cas2015.csv > Casualties_2015.csv
awk 'FNR > 1' Veh2015.csv > Vehicles_2015.csv
rm Acc2015.csv Cas2015.csv Veh2015.csv


# 2016
#
year=2016
unzip rawdata/dftRoadSafety_Accidents_2016.zip
mv dftRoadSafety_Accidents_2016.csv Acc2016.csv
unzip rawdata/dftRoadSafetyData_Casualties_2016.zip
mv Cas.csv Cas2016.csv
unzip rawdata/dftRoadSafetyData_Vehicles_2016.zip
mv Veh.csv Veh2016.csv

# The 2016 accident file has 42 entries with incorrect IDs: `less A.csv  | grep 000000, | wc -l`
#sed -i '' '/000000,/d' A.csv

# Remove the headers
awk 'FNR > 1' "Acc2016.csv" > Accidents_2016.csv
awk 'FNR > 1' "Cas2016.csv" > Casualties_2016.csv
awk 'FNR > 1' "Veh2016.csv" > Vehicles_2016.csv
rm Acc2016.csv Cas2016.csv Veh2016.csv


# 2017
#
year=2017
unzip rawdata/dftRoadSafetyData_Accidents_2017.zip
mv Acc.csv Acc2017.csv
unzip rawdata/dftRoadSafetyData_Casualties_2017.zip
mv Cas.csv Cas2017.csv
unzip rawdata/dftRoadSafetyData_Vehicles_2017.zip
mv Veh.csv Veh2017.csv

# Fix missing NULLs that cause "ERROR 1138 (22004) at line 1249: Invalid use of NULL value"
sed -i.bak 's/20171341E0023,437522,431960,NULL,NULL/20171341E0023,437522,431960,-1.432035,53.782621/' Acc2017.csv
sed -i.bak 's/20171342E0246,422914,433585,NULL,NULL/20171342E0246,422914,433585,-1.653605,53.798070/' Acc2017.csv
sed -i.bak 's/20171343E0199,434011,421718,NULL,NULL/20171343E0199,434011,421718,-1.486440,53.690809/' Acc2017.csv
sed -i.bak 's/20171343E0213,442910,430929,NULL,NULL/20171343E0213,442910,430929,-1.350414,53.772940/' Acc2017.csv
sed -i.bak 's/20171343E0234,433853,435844,NULL,NULL/20171343E0234,433853,435844,-1.487289,53.817779/' Acc2017.csv
sed -i.bak 's/20171343E0303,434139,417940,NULL,NULL/20171343E0303,434139,417940,-1.484915,53.656845/' Acc2017.csv
sed -i.bak 's/20171345E0146,419511,418871,NULL,NULL/20171345E0146,419511,418871,-1.706190,53.665960/' Acc2017.csv
sed -i.bak 's/20171346E0216,423418,437624,NULL,NULL/20171346E0216,423418,437624,-1.645647,53.834350/' Acc2017.csv
sed -i.bak 's/20171349E0197,439803,434169,NULL,NULL/20171349E0197,439803,434169,-1.397136,53.802305/' Acc2017.csv
sed -i.bak 's/20171349E0262,417781,426597,NULL,NULL/20171349E0262,417781,426597,-1.731932,53.735462/' Acc2017.csv
rm Acc2017.csv.bak


# Remove the headers
awk 'FNR > 1' "Acc2017.csv" > Accidents_2017.csv
awk 'FNR > 1' "Cas2017.csv" > Casualties_2017.csv
awk 'FNR > 1' "Veh2017.csv" > Vehicles_2017.csv
rm Acc2017.csv Cas2017.csv Veh2017.csv



# Remove BOM files
perl -e 's/^\xef\xbb\xbf//;' *.csv

# Convert \r\n to \n
dos2unix *.csv



# Combine files, which assumes the ordering of *_20**.csv is in order.
cat Accidents_*.csv > accidents.csv
cat Casualties_*.csv > casualties.csv
cat Vehicles_*.csv > vehicles.csv

# Show counts of original files
wc -l Accidents*
wc -l accidents.csv
echo -e "\n"
wc -l Casualties*
wc -l casualties.csv
echo -e "\n"
wc -l Vehicles*
wc -l vehicles.csv
echo -e "\n"

# Zip files
zip collisions-to$year.zip accidents.csv casualties.csv vehicles.csv

# Clean up
rm *.csv

echo "Please now SFTP the file to the server, e.g. to https://www.cyclestreets.net/collisions-to$year.zip then use that URL in the import UI."
