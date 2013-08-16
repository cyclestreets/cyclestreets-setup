#!/bin/bash
# Script to install CycleStreets Import on Ubuntu
#
# Tested on 13.04 View Ubuntu version using: lsb_release -a
# This script is idempotent - it can be safely re-run without destroying existing data

echo "#	CycleStreets Import System installation $(date)"

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#	This script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The second single line solution from that page is probably good enough as it is unlikely that this script itself will be symlinked.
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPTDIRECTORY=$DIR

# Name of the credentials file
configFile=../.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x ./${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. ./${configFile}

# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Logging
# Use an absolute path for the log file to be tolerant of the changing working directory in this script
setupLogFile=$SCRIPTDIRECTORY/log.txt
touch ${setupLogFile}
echo "#	CycleStreets import installation starting"

# Check Osmosis has been installed
if [ ! -L /usr/local/bin/osmosis ]; then
    echo "#	Please install osmosis first"
    exit 1
fi

# Define import folder
importFolder=${websitesContentFolder}/import

# Switch to import folder
cd ${importFolder}

# Create the settings file if it doesn't exist
phpConfig=".config.php"
if [ ! -e ${phpConfig} ]
then
    cp -p .config.php.template ${phpConfig}
fi

# Setup the config?
if grep IMPORT_USERNAME_HERE ${phpConfig} >/dev/null 2>&1;
then

    # Make the substitutions
    echo "#	Configuring the import ${phpConfig}";
    sed -i \
-e "s/IMPORT_USERNAME_HERE/${mysqlImportUsername}/" \
-e "s/IMPORT_PASSWORD_HERE/${mysqlImportPassword}/" \
-e "s/MYSQL_ROOT_PASSWORD_HERE/${mysqlRootPassword}/" \
-e "s/ADMIN_EMAIL_HERE/${administratorEmail}/" \
-e "s/YOUR_EMAIL_HERE/${mainEmail}/" \
-e "s/YOUR_SALT_HERE/${signinSalt}/" \
	${phpConfig}
fi


# Database setup
# Useful binding
mysql="mysql -uroot -p${mysqlRootPassword} -hlocalhost"

# Users are created by the grant command if they do not exist, making these idem potent.
# The grant is relative to localhost as it will be the apache server that authenticates against the local mysql.
${mysql} -e "grant select, reload, file, super, lock tables, event, trigger on * . * to '${mysqlImportUsername}'@'localhost' identified by '${mysqlImportPassword}' with max_queries_per_hour 0 max_connections_per_hour 0 max_updates_per_hour 0 max_user_connections 0;"

${mysql} -e "grant select , insert , update , delete , create , drop , index , alter , create temporary tables , lock tables , create view , show view , create routine, alter routine, execute on \`planetExtractOSM%\` . * to '${mysqlImportUsername}'@'localhost';"

${mysql} -e "grant select , insert , update , delete , create , drop , index , alter , create temporary tables , lock tables , create view , show view , create routine, alter routine, execute on \`routing%\` . * to '${mysqlImportUsername}'@'localhost';"

${mysql} -e "grant select, insert, update, delete, drop on \`cyclestreets\`.\`map_elevation\` to '${mysqlImportUsername}'@'localhost';"

${mysql} -e "grant insert on \`cyclestreets\`.\`map_error\` to '${mysqlImportUsername}'@'localhost';"

# Elevation data - download 33GB of data, which expands to 180G.
# Tip: These are big files use this to resume a broken copy
# rsync --partial --progress --rsh=ssh user@host:remote_file local_file

# Make sure the target folder exists
mkdir -p ${websitesBackupsFolder}/external

# Check if Ordnance Survey NTF data is desired and that it has not already been downloaded
if [ ! -z "${ordnanceSurveyDataFile}" -a ! -x ${websitesBackupsFolder}/external/${ordnanceSurveyDataFile} ]; then

	# Report
	echo "#	Starting download of OS NTF data 48M"

	# Download
	${asCS} scp ${importMachineAddress}:${websitesBackupsFolder}/external/${ordnanceSurveyDataFile} ${websitesBackupsFolder}/external/

	# Report
	echo "#	Starting installation of OS NTF data"

	# Create folder and unpack
	mkdir -p ${websitesContentFolder}/data/elevation/ordnanceSurvey
	tar xf ${websitesBackupsFolder}/external/${ordnanceSurveyDataFile} -C ${websitesContentFolder}/data/elevation/ordnanceSurvey
fi

# Check if srtm data is desired and that it has not already been downloaded
if [ ! -z "${srtmDataFile}" -a ! -x ${websitesBackupsFolder}/external/${srtmDataFile} ]; then

	# Report
	echo "#	Starting download of SRTM data 8.2G"

	# Download
	${asCS} scp ${importMachineAddress}:${websitesBackupsFolder}/external/${srtmDataFile} ${websitesBackupsFolder}/external/

	# Report
	echo "#	Starting installation of SRTM data"

	# Create folder and unpack
	mkdir -p ${websitesContentFolder}/data/elevation/srtmV4.1/tiff
	tar xf ${websitesBackupsFolder}/external/${srtmDataFile} -C ${websitesContentFolder}/data/elevation/srtmV4.1
fi

# Check if ASTER data is desired and that it has not already been downloaded
if [ ! -z "${asterDataFile}" -a ! -x ${websitesBackupsFolder}/external/${asterDataFile} ]; then

	# Report
	echo "#	Starting download of ASTER data 25G"

	# Download
	${asCS} scp ${importMachineAddress}:${websitesBackupsFolder}/external/${asterDataFile} ${websitesBackupsFolder}/external/

	# Report
	echo "#	Starting installation of ASTER data"

	# Create folder and unpack
	mkdir -p ${websitesContentFolder}/data/elevation/asterV2/tiff
	tar xf ${websitesBackupsFolder}/external/${asterDataFile} -C ${websitesContentFolder}/data/elevation/asterV2
fi

# WIP
echo "#	Reached limit of testing"


# Confirm end of script
msg="#	All now installed $(date)"
echo $msg

# Return true to indicate success
:

# End of file
