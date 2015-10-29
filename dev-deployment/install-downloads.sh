#!/bin/bash
# Installs the downloads server - which provides elevation and other data via downloads.cyclestreets.net

### Stage 1 - general setup

echo "#	CycleStreets: install downloads area"

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
echo "# Downloads area installation $(date)"

# Downloads
downloadsUrl=downloads.cyclestreets.net
downloadsContentFolder=/websites/downloads/content


## Main body

# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Install path to content and go there
mkdir -p "${downloadsContentFolder}/"

# Set permissions
chown -R ${username}:${rollout} ${downloadsContentFolder}/
chmod -R g+w "${downloadsContentFolder}/"

# Switch to it
cd "${downloadsContentFolder}/"

# Create the VirtualHost config if it doesn't exist, and write in the configuration
vhConf=/etc/apache2/sites-available/downloads.conf
if [ ! -f ${vhConf} ]; then
	
	# Create the local virtual host (avoid any backquotes in the text as they'll spawn sub-processes)
	cat > ${vhConf} << EOF
# Redirect to SSL
<VirtualHost *:80>
	ServerName ${downloadsUrl}
	DocumentRoot ${downloadsContentFolder}/
	CustomLog /websites/www/logs/${downloadsUrl}-access.log combined
	ErrorLog /websites/www/logs/${downloadsUrl}-error.log
	
	# Redirect to HTTPS host
	RewriteEngine On
	RewriteCond %{HTTPS} !=on
	RewriteRule .* https://%{HTTP_HOST}%{REQUEST_URI} [R,L]
</VirtualHost>

# SSL host
<VirtualHost *:443>
	ServerName ${downloadsUrl}
	DocumentRoot ${downloadsContentFolder}/
	CustomLog /websites/www/logs/${downloadsUrl}-access.log combined
	ErrorLog /websites/www/logs/${downloadsUrl}-error.log
	
	# Enable SSL
	SSLEngine on
	SSLCertificateFile	/etc/apache2/sslcerts/STAR_cyclestreets_net.crt
	SSLCertificateKeyFile	/etc/apache2/sslcerts/cyclestreets.net.key
	SSLCACertificateFile	/etc/apache2/sslcerts/intermediates.cer
	
	# Add webserver-level password protection
	Use MacroPasswordProtectSite /
</VirtualHost>
EOF

fi

# Enable the VirtualHost; this is done manually to ensure the ordering is correct
if [ ! -L /etc/apache2/sites-enabled/downloads.conf ]; then
	ln -s ${vhConf} /etc/apache2/sites-enabled/downloads.conf
fi

# Create a README file
readme=${downloadsContentFolder}/readme.txt
if [ ! -f ${readme} ]; then

	# Create the README (avoid any backquotes in the text as they'll spawn sub-processes)
	cat > ${readme} << EOF
downloads.cyclestreets.net
=====================

Contains sources of elevation data from:

Ordnance Survey - Great Britain

SRTM - NASA - worldwide between 60 degrees south and 60 degrees north

ASTER - Japanese data from 60 degrees north to 83 degrees north

EOF

fi

# Add an index file
if [ ! -f ${downloadsContentFolder}/index.html ]; then
        echo -e '<p>There is no index of files in this location.</p>' >> ${downloadsContentFolder}/index.html
fi

# Reload apache
service apache2 reload

# Report completion
echo "#	Installing downloads area completed"

# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

# End of file
