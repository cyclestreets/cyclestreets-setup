#!/bin/bash
# Script to install CycleStreets Import on Ubuntu
#
# Tested on 13.04 View Ubuntu version using: lsb_release -a
# This script is (NOT YET) idempotent - it can be safely re-run without destroying existing data

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

# Logging
# Use an absolute path for the log file to be tolerant of the changing working directory in this script
setupLogFile=$SCRIPTDIRECTORY/log.txt
touch ${setupLogFile}
echo "#	CycleStreets import installation in progress, follow log file with: tail -f ${setupLogFile}"
echo "#	CycleStreets import installation $(date)" >> ${setupLogFile}

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
	${phpConfig}
fi




# Database setup
# Useful binding
mysql="mysql -uroot -p${mysqlRootPassword} -hlocalhost"



# Users are created by the grant command if they do not exist, making these idem potent.
# The grant is relative to localhost as it will be the apache server that authenticates against the local mysql.
#${mysql} -e "CREATE USER 'import'@'%' IDENTIFIED BY '***';
#grant select, insert, update, delete, execute on cyclestreets.* to '${mysqlWebsiteUsername}'@'localhost' identified by '${mysqlWebsitePassword}';" >> ${setupLogFile}


echo "#	Reached limit of testing"



# Confirm end of script
msg="#	All now installed $(date)"
echo $msg >> ${setupLogFile}
echo $msg

# Return true to indicate success
:

# End of file
