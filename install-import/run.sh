#!/bin/bash
# Script to install CycleStreets import sources and data on Ubuntu
#
# Written for Ubuntu Server 16.04 LTS. View Ubuntu version using: lsb_release -a
# This script is idempotent - it can be safely re-run without destroying existing data
# It should be run after the website system has been installed.

echo "#	$(date)	CycleStreets Import System installation"

# The script should be run using sudo
if [ "$(id -u)" != "0" ]; then
    echo "#	This script must be run using sudo from an account that has access to the CycleStreets Git repo." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e


### DEFAULTS ###

# Central PhpMyAdmin installation
phpmyadminMachine=

# MySQL settings for when the server is running an import or serving routes
# Values can be written as eg: 1*1024*1024*1024
# E.g London should work with 2G, but whole of UK needs 10G.
import_key_buffer_size=2*1024*1024*1024
import_max_heap_table_size=2*1024*1024*1024
import_tmp_table_size=2*1024*1024*1024

# Password for cyclestreets@downloads.cyclestreets.net to download extra data such as elevations
datapassword=

# Elevation datasources - add to list (source must be present on downloads server) or comment out if not wanted
elevationDatasources=(
#	'alos.tar.bz2'
#	'prague.tar.bz2'
	'osterrain50.tar.bz2'
#	'srtm.tar.bz2'
#	'aster.tar.bz2'
)

# Archive db
archiveDb=

# External db
externalDb=

### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The second single line solution from that page is probably good enough as it is unlikely that this script itself will be symlinked.
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Use this to remove the ../
ScriptHome=$(readlink -f "${DIR}/..")

# Change to the script's folder
cd ${ScriptHome}

# Name of the credentials file
configFile=${ScriptHome}/.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x ${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist or is not executable. Copy your own based on the ${configFile}.template file, or create a symlink to the configuration."
    exit 1
fi

# Load the credentials
. ${configFile}

# Check required config
if [ -z "${baseOS}" ]; then
    echo "#	Please set a value for baseOS in the config file."
    exit 1
fi

# Check required config
if [ -z "${importContentFolder}" ]; then
    echo "#	Please set a value for importContentFolder in the config file."
    exit 1
fi


# Check required config
if [ -z "${mysqlImportUsername}" ]; then
    echo "#	Please set a value for mysqlImportUsername in the config file."
    exit 1
fi

# Check required config
if [ -z "${cyclestreetsProfileFolder}" ]; then
    echo "#	Please set a value for cyclestreetsProfileFolder in the config file."
    exit 1
fi


echo "#	Installing CycleStreets import for base OS: ${baseOS}"

# Install a base webserver machine with webserver software (Apache, PHP, MySQL), relevant users and main directory
. ${ScriptHome}/utility/installBaseWebserver.sh

# Load common install script
. ${ScriptHome}/utility/installCommon.sh

# Need to add a check that CycleStreets main installation has been completed
if [ ! -d "${websitesContentFolder}" ]; then
    echo "#	Please install the main CycleStreets repo first"
    exit 1
fi


## Repo: cyclestreets-profiles

# Add the path to content
mkdir -p ${cyclestreetsProfileFolder}

# Switch to content folder
cd ${cyclestreetsProfileFolder}


# SUDO_USER is the name of the user that invoked the script using sudo
# !! This technique which is a bit like doing an 'unsudo' is messy.
chown ${SUDO_USER}:${rollout} ${cyclestreetsProfileFolder}

# Create/update the repository from the sudo-invoking user's account
# !! This may prompt for git username / password.
if [ ! -d ${cyclestreetsProfileFolder}/.git ]
then
	su - ${SUDO_USER} -c "git clone ${repoOrigin}cyclestreets/cyclestreets-profiles.git ${cyclestreetsProfileFolder}"
	git config --global --add safe.directory ${cyclestreetsProfileFolder}

else
    # Set permissions before the update
    chgrp -R rollout ${cyclestreetsProfileFolder}/.git
    su - ${SUDO_USER} -c "cd ${cyclestreetsProfileFolder} && git pull"
fi

# Add cronned update of the repo
cp /opt/cyclestreets-profiles/cyclestreets-profiles-update.cron /etc/cron.d/cyclestreets-profiles-update
chown root.root /etc/cron.d/cyclestreets-profiles-update
chmod 0600 /etc/cron.d/cyclestreets-profiles-update




# GDAL - which provides tools for reading elevation data
# A backported version (for Ubuntu 16.04 LTS) that provides some json options is available, see:
# https://stackoverflow.com/a/41613466/225876
$packageInstall gdal-bin

# For the time being [:] 14 Apr 2015 the import is a symbolic link
if [ ! -L "${importContentFolder}" ]; then

    # Create the symlink
    ln -s ${websitesContentFolder}/import ${importContentFolder}

fi

# Switch to import folder
cd ${importContentFolder}

#	Ensure directory for new routing editions
mkdir -p ${importContentFolder}/output
chown -R ${username}.${rollout} ${importContentFolder}/output

# Setup a mysql configuration file which will allow the import user to run mysql commands without supplying credentials on the command line
myImportCnfFile=${importContentFolder}/.myImportUserCredentials.cnf
if [ ! -e ${myImportCnfFile} ]; then

    # Create config file
    cat > ${myImportCnfFile} << EOF
[client]
user=${mysqlImportUsername}
password='${mysqlImportPassword}'
# Best to avoid setting a database as this can confuse scripts, ie leave commented out:
#database=

[mysql]
# Equiv to -A at startup, stops tabs trying to autocomplete
no-auto-rehash
EOF

    # Ownership
    chown ${username}.${rollout} ${myImportCnfFile}

    # Remove other readability
    chmod o-r ${myImportCnfFile}
fi

# Create the settings file if it doesn't exist
phpConfig=.config.php
if [ ! -e ${phpConfig} ]
then
    # Make a copy from the config template
    cp -p .config.php.template ${phpConfig}
fi

# Setup the configuration file
if grep CONFIGURED_BY_HERE ${phpConfig} >/dev/null 2>&1;
then

    # Make the substitutions
    echo "#	Configuring the import ${phpConfig}";
    sed -i \
-e "s|CONFIGURED_BY_HERE|Configured by cyclestreets-setup for csHostname: ${csHostname}${sourceConfig}|" \
-e "s/IMPORT_USERNAME_HERE/${mysqlImportUsername}/" \
-e "s/IMPORT_PASSWORD_HERE/${mysqlImportPassword}/" \
-e "s/MYSQL_ROOT_PASSWORD_HERE/${mysqlRootPassword}/" \
-e "s/ADMIN_EMAIL_HERE/${administratorEmail}/" \
-e "s/MySQL_KEY_BUFFER_SIZE_HERE/${import_key_buffer_size}/" \
-e "s/MySQL_MAX_HEAP_TABLE_SIZE_HERE/${import_max_heap_table_size}/" \
-e "s/MySQL_TMP_TABLE_SIZE_HERE/${import_tmp_table_size}/" \
-e "s|CYCLESTREETSPROFILEFOLDER_HERE|${cyclestreetsProfileFolder}|" \
	${phpConfig}
fi

# Check Osmosis has been installed
# To force a reinstall delete the current installation:
# rm -r /usr/local/bin/osmosis
# rm -r "`readlink -f /usr/local/osmosis/current`"
# rm -r /usr/local/osmosis/current
# October 2020: 0.48.3 is needed for Ubuntu 20.04 / MySQL 8 which uses updated connector/J that avoids the removed query_cache_size.
osmosisVersion=0.48.3
if [ ! -L /usr/local/bin/osmosis ]; then

    # Announce Osmosis installation
    # !! Osmosis uses MySQL and that needs to be configured to use character_set_server=utf8 and collation_server=utf8_unicode_ci which is currently set up (machine wide) by website installation.
    echo "#	$(date)	CycleStreets / Osmosis installation"

    # Prepare the apt index
    $packageUpdate > /dev/null

    # Osmosis requires java
    $packageInstall default-jre

    # Create folder
    mkdir -p /usr/local/osmosis

    # wget the latest to here
    if [ ! -e /usr/local/osmosis/osmosis-latest.tgz ]; then
	wget -O /usr/local/osmosis/osmosis-latest.tgz https://github.com/openstreetmap/osmosis/releases/download/${osmosisVersion}/osmosis-${osmosisVersion}.tgz
    fi

    # Create a folder for the new version
    mkdir -p /usr/local/osmosis/osmosis-${osmosisVersion}

    # Unpack into it
    tar xzf /usr/local/osmosis/osmosis-latest.tgz -C /usr/local/osmosis/osmosis-${osmosisVersion}

    # Remove the download archive
    rm -f /usr/local/osmosis/osmosis-latest.tgz

    # Repoint current to the new version
    rm -f /usr/local/osmosis/current

    # Whatever the version number is here
    ln -s /usr/local/osmosis/osmosis-${osmosisVersion} /usr/local/osmosis/current

    # This last bit only needs to be done first time round, not for upgrades. It keeps the binary pointing to the current osmosis.
    if [ ! -L /usr/local/bin/osmosis ]; then
	ln -s /usr/local/osmosis/current/bin/osmosis /usr/local/bin/osmosis
    fi

    # Announce completion
    echo "#	Completed installation of osmosis"
fi

# Osmosis config file
# https://wiki.openstreetmap.org/wiki/Osmosis/Tuning
if [ ! -e /home/${username}/.osmosis ]; then
    echo "JAVACMD_OPTIONS=-server" > /home/${username}/.osmosis
    chown ${username}.${username} /home/${username}/.osmosis
fi

# Users are created by the grant command if they do not exist, making these idem potent.
echo "#	Grants"

# Useful binding
# The defaults-extra-file is a positional argument which must come first.
superMysql="mysql --defaults-extra-file=${mySuperCredFile} -hlocalhost"

# The grant is relative to localhost as it will be the apache server that authenticates against the local mysql.
${superMysql} -e "create user if not exists '${mysqlImportUsername}'@'localhost' identified with mysql_native_password by '${mysqlImportPassword}' with max_queries_per_hour 0 max_connections_per_hour 0 max_updates_per_hour 0 max_user_connections 0;"
${superMysql} -e "grant select, reload, file, super, lock tables, event, trigger on * . * to '${mysqlImportUsername}'@'localhost';"

# Useful binding
importpermissions="grant select, insert, update, delete, create, drop, index, alter, create temporary tables, lock tables, create view, show view, create routine, alter routine, execute on"

${superMysql} -e "${importpermissions} \`planet%\` . * to '${mysqlImportUsername}'@'localhost';"
${superMysql} -e "${importpermissions} \`routing%\` . * to '${mysqlImportUsername}'@'localhost';"
${superMysql} -e "${importpermissions} \`${archiveDb}\` . * to '${mysqlImportUsername}'@'localhost';"
${superMysql} -e "${importpermissions} \`${externalDb}\` . * to '${mysqlImportUsername}'@'localhost';"

# Elevation data - these are often multiple GB in size
# Tip: These are big files; so can use this to resume a broken copy:
#  rsync --partial --progress --rsh=ssh user@host:remote_file local_file

# Loop through each enabled elevation datasource
for elevationDatasourceFile in "${elevationDatasources[@]}"; do
	
	# Split into subdirectory and filetype, e.g. srtm.tar.bz2 would have srtm/ and tar.bz2 ; see: http://unix.stackexchange.com/a/53315/168900
	IFS='.' read -r subdirectory filetype <<< "${elevationDatasourceFile}"
	
	# Determine the expected location, where the subdirectory is the same as the filename base, e.g. srtm/ for srtm.tar.bz2
	unpackFolder="${importContentFolder}/data/elevation/${subdirectory}/"
	if [ ! -d ${unpackFolder} ]; then
		
		# Obtain the file
		echo "# Starting download of ${elevationDatasourceFile} elevation data file to ${websitesBackupsFolder}"
		wget https://cyclestreets:${datapassword}@downloads.cyclestreets.net/elevations/${subdirectory}/${elevationDatasourceFile} -O ${websitesBackupsFolder}/${elevationDatasourceFile}
		
		# Create folder and unpack
		echo "# Unpacking ${subdirectory} elevation data to ${unpackFolder}"
		mkdir -p ${unpackFolder}
		case "${filetype}" in
			'tar.bz2' )
				# note: create files using using `tar -cvjSf source.tar.bz2 file.tiff`
				tar -xf ${websitesBackupsFolder}/${elevationDatasourceFile} -C ${unpackFolder}
			;;
			'bz2' )
				cp -p ${websitesBackupsFolder}/${elevationDatasourceFile} ${unpackFolder}
				cd ${unpackFolder}
				bunzip2 ${elevationDatasourceFile}
			;;
		esac
		
		# Ensure files can be read by the webserver
		chown -R ${username}.${rollout} ${unpackFolder}
		
		# Delete the downloaded file to free up space
		rm ${websitesBackupsFolder}/${elevationDatasourceFile}
	fi
done

# Bearing Turn Pattern table download
# The import system can generate this table, but it is quicker to obtain it as a download.
# Skip if the table already exists
if ! ${superMysql} --batch --skip-column-names -e "SHOW tables LIKE 'lib_bearingPatternDetent'" csExternal | grep lib_bearingPatternDetent  > /dev/null 2>&1
then
    # Obtain the file, which is created using:
    # mysqldump csExternal lib_bearingPatternDetent | bzip2 > bearingPatternDetent.sql.bz2
    bearingTableFile=bearingPatternDetent.sql.bz2
    echo "# Starting download of ${bearingTableFile} bearing data file to ${websitesBackupsFolder}"
    wget https://cyclestreets:${datapassword}@downloads.cyclestreets.net/${bearingTableFile} -O ${websitesBackupsFolder}/${bearingTableFile}

    # Unpack and remove file
    echo "# Unpacking bearing pattern turn data file into external db"
    bunzip2 < ${websitesBackupsFolder}/${bearingTableFile} | ${superMysql} csExternal
    rm ${websitesBackupsFolder}/${bearingTableFile}
fi

# Fetching dependencies
echo "#	$(date)	Fetching dependencies"
$packageInstall libboost-dev cmake gcc g++ python3-dev python3-pip make doxygen graphviz

# Upgrade pip
python3 -m pip install --upgrade pip

# Python package for encoding coordinate lists
python3 -m pip install polyline

# Build bridges
cd ${importContentFolder}/graph
./buildbridge.sh

# Build islands
cd ${importContentFolder}/graph/islands_cpp
./build.sh

# Developer feature for finding definitions in code
if [ -n "$tagsLanguages" ]; then

    # Install the tags generator
    $packageInstall exuberant-ctags

    # Parse the tags
    su - ${SUDO_USER} -c "cd ${websitesContentFolder} && ctags -e -R --languages=$tagsLanguages"
fi

# Install firewall
. ${ScriptHome}/utility/installFirewall.sh

# Confirm end of script
cd ${importContentFolder}
echo "#	$(date)	All now installed."

# Return true to indicate success
:

# End of file
