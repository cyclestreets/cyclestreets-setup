#!/bin/bash
# Script to install CycleStreets import sources and data on Ubuntu
#
# Written for Ubuntu Server 16.04 LTS. View Ubuntu version using: lsb_release -a
# This script is idempotent - it can be safely re-run without destroying existing data
# It should be run after the website system has been installed.

echo "#	$(date)	CycleStreets Import System installation"

# The script should be run using sudo
if [ "$(id -u)" != "0" ]; then
    echo "#	This script must be run using sudo from an account that has access to the CycleStreets svn repo." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

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
    echo "#	The config file, ${configFile}, does not exist or is not excutable. Copy your own based on the ${configFile}.template file, or create a symlink to the configuration."
    exit 1
fi

# Load the credentials
. ${configFile}

# Check a base OS has been defined
if [ -z "${baseOS}" ]; then
    echo "#	Please define a value for baseOS in the config file."
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

# GDAL - which provides tools for reading elevation data
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
	${phpConfig}
fi

# Check Osmosis has been installed
if [ ! -L /usr/local/bin/osmosis ]; then

    # Announce Osmosis installation
    # !! Osmosis uses MySQL and that needs to be configured to use character_set_server=utf8 and collation_server=utf8_unicode_ci which is currently set up (machine wide) by website installation.
    echo "#	$(date)	CycleStreets / Osmosis installation"

    # Prepare the apt index
    apt-get update > /dev/null

    # Osmosis requires java
    apt-get -y install openjdk-9-jre

    # Create folder
    mkdir -p /usr/local/osmosis

    # wget the latest to here
    if [ ! -e /usr/local/osmosis/osmosis-latest.tgz ]; then
	wget -O /usr/local/osmosis/osmosis-latest.tgz http://dev.openstreetmap.org/~bretth/osmosis-build/osmosis-latest.tgz
    fi

    # Create a folder for the new version
    mkdir -p /usr/local/osmosis/osmosis-0.43.1

    # Unpack into it
    tar xzf /usr/local/osmosis/osmosis-latest.tgz -C /usr/local/osmosis/osmosis-0.43.1

    # Remove the download archive
    rm -f /usr/local/osmosis/osmosis-latest.tgz

    # Repoint current to the new install
    rm -f /usr/local/osmosis/current

    # Whatever the version number is here - replace the 0.43.1
    ln -s /usr/local/osmosis/osmosis-0.43.1 /usr/local/osmosis/current

    # This last bit only needs to be done first time round, not for upgrades. It keeps the binary pointing to the current osmosis.
    if [ ! -L /usr/local/bin/osmosis ]; then
	ln -s /usr/local/osmosis/current/bin/osmosis /usr/local/bin/osmosis
    fi

    # Announce completion
    echo "#	Completed installation of osmosis"
fi

# Users are created by the grant command if they do not exist, making these idem potent.
# The grant is relative to localhost as it will be the apache server that authenticates against the local mysql.
${superMysql} -e "grant select, reload, file, super, lock tables, event, trigger on * . * to '${mysqlImportUsername}'@'localhost' identified by '${mysqlImportPassword}' with max_queries_per_hour 0 max_connections_per_hour 0 max_updates_per_hour 0 max_user_connections 0;"

# Useful binding
importpermissions="grant select, insert, update, delete, create, drop, index, alter, create temporary tables, lock tables, create view, show view, create routine, alter routine, execute on"

${superMysql} -e "${importpermissions} \`planetExtractOSM%\` . * to '${mysqlImportUsername}'@'localhost';"
${superMysql} -e "${importpermissions} \`routing%\` . * to '${mysqlImportUsername}'@'localhost';"

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


# Confirm end of script
echo "#	$(date)	All now installed."

# Return true to indicate success
:

# End of file
