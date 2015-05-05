#!/bin/bash
# Installs the data server - which provides elevation data via data.cyclestreets.net

### Stage 1 - general setup

echo "#	CycleStreets: install data"

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

# Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 9 || { echo '#	An installation is already running' ; exit 1; }


### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The multi-line method of geting the script directory is needed because this script is likely symlinked from cron
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
    echo "#	The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. $SCRIPTDIRECTORY/${configFile}

# Announce starting
echo "# Data installation $(date)"

# !! These will need to appear in the config.sh
# Data
dataUrl=data.cyclestreets.net
dataContentFolder=/websites/data/content


# Check the options
if [ -z "${dataUrl}" -o -z "${dataContentFolder}" ]; then
    echo "#	The data options are not configured, abandoning installation."
    exit 1
fi


## Main body

# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Install path to content and go there
mkdir -p "${dataContentFolder}"

# Make the folder group writable
chmod -R g+w "${dataContentFolder}"

# Switch to it
cd "${dataContentFolder}"

# Create the VirtualHost config if it doesn't exist, and write in the configuration
vhConf=/etc/apache2/sites-available/data.conf
if [ ! -f ${vhConf} ]; then

    # Create the local virtual host (avoid any backquotes in the text as they'll spawn sub-processes)
    cat > ${localVirtualHostFile} << EOF
# Data
<VirtualHost *:80>

        # Available URL(s)
        ServerName ${dataUrl}

        # Logging
        CustomLog /websites/www/logs/data-access.log combined
        ErrorLog /websites/www/logs/data-error.log

        # Where the files are located
        DocumentRoot ${dataContentFolder}

        # Provide a directory listing
        <Directory ${dataContentFolder}>
                   Options Indexes
        </Directory>

        # Password protection
        <Directory ${dataContentFolder}>
                   AuthUserFile /websites/data/.htpasswd
                   AuthType Basic
                   AuthName "CycleStreets data"
                   Require valid-user
        </Directory>
</VirtualHost>
EOF

fi

# Enable the VirtualHost; this is done manually to ensure the ordering is correct
if [ ! -L /etc/apache2/sites-enabled/750-data.conf ]; then
    ln -s ${vhConf} /etc/apache2/sites-enabled/750-data.conf
fi

# Create a readme file
readme=${dataContentFolder}/readme.txt
if [ ! -f ${readme} ]; then

    # Create the local virtual host (avoid any backquotes in the text as they'll spawn sub-processes)
    cat > ${readme} << EOF
data.cyclestreets.net
=====================

Contains sources of elevation data from:

Ordnance Survey - Great Britain

SRTM - NASA - worldwide between 60 degrees south and 60 degrees north

ASTER - Japanese data from 60 degrees north to 83 degrees north

EOF

fi


# Reload apache
service apache2 reload

# Report completion
echo "#	Installing data completed"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
