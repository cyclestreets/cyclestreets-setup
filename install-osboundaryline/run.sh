#!/bin/bash
# Script Integrate OS Boundary Line from OS open data and takes about 20 minutes to run.
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

# Lock directory
lockdir=/var/lock/cyclestreets
mkdir -p $lockdir


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
echo "# OS Boundary Line installation $(date)"


## Main body

# Update sources and packages
apt -y update
apt install -y unzip

# Obtain and unzip the data from My Society
cd /tmp
mkdir boundary-line
cd boundary-line
wget http://parlvid.mysociety.org/os/boundary-line/bdline_gpkg_gb-2020-05.zip
unzip bdline_gpkg_gb*.zip

# Install GDAL
apt install -y gdal-bin
ogrinfo --version

# Import gpkg data to MySQL
mysql -u root -p${mysqlRootPassword} -e "CREATE DATABASE IF NOT EXISTS osboundaryline;"

# This imports all tables, and converts geometries to WGS84 (SRID=4326)
# Use -skipfailures for complex shapes such as Shetland
ogr2ogr -f MySQL MySQL:osboundaryline,user=root,password=$mysqlRootPassword data/bdline_gb.gpkg -t_srs EPSG:4326 -update -overwrite -lco GEOMETRY_NAME=geometry -lco ENGINE=MyISAM -skipfailures

# Permit the website to view the database
mysql -u root -p${mysqlRootPassword} -e "grant select, insert, update, delete, create, execute on osboundaryline.* to 'website'@'localhost';"

# Report completion
echo "#	Installing OS Boundary Line completed"

# End of file
