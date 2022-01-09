#!/bin/bash
# Script Integrate OS Boundary Line from OS open data and takes about 2 hours to run.
usage()
{
    cat << EOF

SYNOPSIS
	$0 -h

OPTIONS
	-h Show this message

DESCRIPTION
	Import whole GeoPackage direct to MySQL.

EOF
}

# http://wiki.bash-hackers.org/howto/getopts_tutorial
# An opening colon in the option-string switches to silent error reporting mode.
# Colons after letters indicate that those options take an argument e.g. m takes an email address.
while getopts "hq" option ; do
    case ${option} in
        h) usage; exit ;;
	# Missing expected argument
	:)
	    echo "Option -$OPTARG requires an argument." >&2
	    exit 1
	    ;;
	\?) echo "Invalid option: -$OPTARG" >&2 ; exit ;;
    esac
done

# After getopts is done, shift all processed options away with
shift $((OPTIND-1))


echo "#	CycleStreets: Import whole GeoPackage direct to MySQL."

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#     This script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e


### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The multi-line method of geting the script directory is needed to enable the script to be called from elsewhere.
SOURCE="${BASH_SOURCE[0]}"
DIR="$( dirname "$SOURCE" )"
while [ -h "$SOURCE" ]
do
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
  DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPTDIRECTORY=$DIR

# Define the location of the credentials file relative to script directory
configFile=../.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x $SCRIPTDIRECTORY/${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist or is not executable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. $SCRIPTDIRECTORY/${configFile}

# Announce starting
echo "# $(date)	OS Boundary Line installation"


## Main body

# Update sources and packages
apt -y update
apt install -y unzip gdal-bin

# Source of the Boundary Line data - it should be in a GeoPackage format
# Directly from OS
# https://osdatahub.os.uk/downloads/open/BoundaryLine
sourceUrl="https://api.os.uk/downloads/v1/products/BoundaryLine/downloads?area=GB&format=GeoPackage&redirect"

# Alternatively from My Society
# This Oct 2021 version is the latest in the GeoPackage format on their site,
# but did not have the GeoPackage format when tried on 8 Dec 2021 18:34:54.
# sourceUrl="https://parlvid.mysociety.org/os/boundary-line/bdline_gb-2021-10.zip"

cd /tmp
mkdir -p boundary-line
cd boundary-line
wget --output-document=bdline_gpkg_gb.zip "${sourceUrl}"
unzip -u bdline_gpkg_gb*.zip

# Prepare the database
echo "#	$(date)	Prepare osboundaryline database"
mysql -u root -p${mysqlRootPassword} < $SCRIPTDIRECTORY/osboundaryline.sql

# Import gpkg data to MySQL
# This imports all tables, and converts geometries to WGS84 (SRID=4326)
echo "#	$(date)	Import GeoPackage into MySQL"
ogr2ogr -f MySQL MySQL:osboundaryline,user=root,password=$mysqlRootPassword data/bdline_gb.gpkg -t_srs EPSG:4326 -update -overwrite -lco GEOMETRY_NAME=geometry -lco ENGINE=MyISAM -progress

# Convert SRID
echo "#	$(date)	Convert to SRID zero to use MySQL spatial index and all spatial functions (takes about an hour)"
mysql -u root -p${mysqlRootPassword} osboundaryline < $SCRIPTDIRECTORY/convert_srid.sql

# Apply optimizations
echo "#	$(date)	Boundary line optimizations"
mysql -u root -p${mysqlRootPassword} osboundaryline < $SCRIPTDIRECTORY/optimizations.sql

# Ensure that CycleStreets uses the new boundary ids
echo "#	$(date)	Fix CycleStreets boundary ids"
mysql -u root -p${mysqlRootPassword} cyclestreets < ${websitesContentFolder}/documentation/schema/boundarylineids.sql

# Highway authorities
echo "#	$(date)	Highway authorities"
mysql -u root -p${mysqlRootPassword} osboundaryline < $SCRIPTDIRECTORY/highwayAuthorities.sql

# Report completion
echo "#	$(date)	OS Boundary Line completed"


# Ireland
# https://data-osi.opendata.arcgis.com/datasets/14251ccbb15d4d99b984b5c956bb835a_0/explore?location=53.422627%2C-8.258350%2C7.28
echo "#	$(date)	Ordnance Survey of Ireland"

# Get the data
cd /tmp
mkdir -p ireland_counties
cd ireland_counties
wget -O Counties_-_OSi_National_Statutory_Boundaries.geojson https://opendata.arcgis.com/datasets/14251ccbb15d4d99b984b5c956bb835a_0.geojson

# Load into csExternal
ogr2ogr -f MySQL "MySQL:csExternal,user=root,password=$mysqlRootPassword" Counties_-_OSi_National_Statutory_Boundaries.geojson -nln 'ireland_counties' -t_srs EPSG:4326 -update -overwrite -lco FID=id -lco GEOMETRY_NAME=geometry -progress

# Convert SRID
echo "#	$(date)	Convert to SRID zero to use MySQL spatial index and all spatial functions"
mysql -u root -p${mysqlRootPassword} csExternal < $SCRIPTDIRECTORY/ireland_convert_srid.sql

# Report completion
echo "#	$(date) Ireland counties loaded"



# Northern Ireland
echo "#	$(date)	Ordnance Survey Northern Ireland"

# Get the data
cd /tmp
mkdir -p osni
cd osni
wget -O OSNI_Open_Data_-_Largescale_Boundaries_-_Local_Government_Districts_2012.geojson https://osni-spatialni.opendata.arcgis.com/datasets/eaa08860c50045deb8c4fdc7fa3dac87_2.geojson?outSR=%7B%22latestWkid%22%3A29902%2C%22wkid%22%3A29900%7D

# Load into csExternal
ogr2ogr -f MySQL "MySQL:csExternal,user=root,password=$mysqlRootPassword" OSNI_Open_Data_-_Largescale_Boundaries_-_Local_Government_Districts_2012.geojson -nln 'northern_ireland' -t_srs EPSG:4326 -update -overwrite -lco FID=id -lco GEOMETRY_NAME=geometry -progress


# Convert SRID
echo "#	$(date)	Convert to SRID zero to use MySQL spatial index and all spatial functions"
mysql -u root -p${mysqlRootPassword} csExternal < $SCRIPTDIRECTORY/northern_ireland_convert_srid.sql

# Report completion
echo "#	$(date) Northern Ireland districts loaded"



# Report completion
echo "#	$(date) All regions completed."
echo "#	Please remove unwanted files from:"
echo "#	/tmp/boundary-line"
echo "#	/tmp/ireland_counties"
echo "#	/tmp/osni"

# End of file
