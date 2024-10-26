#!/bin/bash
# Script to install CycleStreets on Ubuntu 20.04.1 LTS
#
# (View Ubuntu version using 'lsb_release -a')
# This script is idempotent - it can be safely re-run without destroying existing data

# Announce start
echo "#	$(date)	CycleStreets installation"

# Ensure this script is run using sudo
if [ "$(id -u)" != "0" ]; then
    echo "#	This script must be run using sudo from an account that has access to the CycleStreets Git repo."
    exit 1
fi

# Bomb out if something goes wrong
set -e


### DEFAULTS ###

# Host port setting
# Used when setting up a virtual server inside a developer machine and port forwarding is used to connect, has a value like: 3080
hostPort=

# Central PhpMyAdmin installation
phpmyadminMachine=

# Legacy: a string used to encrypt user passwords
signinSalt=

# Exim email
# Basically, use the 'internet' (direct delivery) mode here for a developer setup
#!# Simplify this block to be a single setting like profile='developer'/'deployment' and write out settings (based on those below) accordingly
dc_eximconfig_configtype='internet'  # Use 'internet' for direct delivery, or 'satellite' if mail is delivered by your ISP
dc_local_interfaces=''               # Use '' if using 'internet' or '127.0.0.1' if using 'satellite' above
dc_readhost='cyclestreets.net'       # Set to 'cyclestreets.net'
dc_smarthost=''                      # Use '' if using 'internet' or 'mx.yourispmailhost.com' if using 'satellite' above

# Archive db
archiveDb=

# Password for cyclestreets@downloads.cyclestreets.net to download external data
datapassword=

# External database (leave empty if not wanted)
externalDb=

# Batch database: csBatch (leave empty if not wanted)
batchDb=

# Face recognition and number plate recognition
imageRecognitionComponent=

# Html to PDF
htmlToPdfComponent=

# Potlatch
potlatchComponent=

# Default dev site rewrite
devSiteRewrite=

# Extra options for Contol drop down list
extraApiV2urls=

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

# Check a base OS has been defined
if [ -z "${baseOS}" ]; then
    echo "#	Please define a value for baseOS in the config file."
    exit 1
fi
echo "#	Installing CycleStreets website for base OS: ${baseOS}"

# Default main email if it has not been set
if [ -z "${mainEmail}" ]; then
    mainEmail=$administratorEmail
fi

# Default repository origin if it has not been set
if [ -z "${repoOrigin}" ]; then
    repoOrigin=https://github.com/
fi

# Install a base webserver machine with webserver software (Apache, PHP, MySQL), relevant users and main directory
. ${ScriptHome}/utility/installBaseWebserver.sh

# Load common install script
. ${ScriptHome}/utility/installCommon.sh

# Switch to content folder
cd ${websitesContentFolder}

# PHP packages
# Ensure Zip support, needed by collision data import
# ImageMagick is used to provide enhanced maplet drawing. It is optional - if not present gd is used instead.
apt -y install php-json php-yaml php-zip imagemagick php-imagick

# Install Composer packages
composer install

# Enable mod_deflate for Apache
sudo a2enmod deflate
service apache2 restart

# Install Python
echo "#	Installing python"
# These are used by deployment scripts to correspond with the routing servers via xml
apt -y install python3 php-xmlrpc php-curl python3-dev python-argparse python3-pip curl libxml-xpath-perl

# Upgrade pip
python3 -m pip install --upgrade pip

# Python package for encoding coordinate lists
python3 -m pip install polyline

# Utilities
echo "#	Some utilities"

# Spreadsheet->CSV conversion
apt -y install gnumeric

# Image recognition
if [ -n "${imageRecognitionComponent}" ]; then

    # ffmpeg; this has been restored in 16.04 as an official package
    apt -y install ffmpeg python3-opencv opencv-data

    # Facial recognition; see: https://gitlab.com/wavexx/facedetect and https://www.thregr.org/~wavexx/software/facedetect/
    if [ ! -e /usr/local/bin/facedetect ] ; then
	wget -P /usr/local/bin https://gitlab.com/wavexx/facedetect/raw/master/facedetect
	chmod +x /usr/local/bin/facedetect
    fi
    # Number plate recognition; see: https://github.com/openalpr/openalpr
    apt -y install openalpr
fi

# HTML to PDF conversion
if [ -n "${htmlToPdfComponent}" ]; then
    apt -y install wkhtmltopdf
fi

# On Mac OSX, use the following as documented at http://stackoverflow.com/a/14043085/180733 and https://gist.github.com/semanticart/389944e2bcdba5424e01
# brew install https://gist.githubusercontent.com/semanticart/389944e2bcdba5424e01/raw/9ed120477b57daf10d7de6d585d49b2017cd6955/wkhtmltopdf.rb

# Install Potlatch editor, if not already present
if [ -n "${potlatchComponent}" ]; then

    #!# Ideally we would:
    #    1) Pull down the latest dev code from https://github.com/openstreetmap/potlatch2
    #    2) Compile using Flex as detailed in the README, using the Flex install instructions at http://thomas.deuling.org/2011/05/install-flex-sdk-under-ubuntu-linux/
    #    3) Add in the local config, which are believed to be map_features.xml (position of transport block moved) and vectors.xml (which defines the external sources); possibly there are other files - needs to be checked
    if [ ! -f "${websitesContentFolder}/edit/editor/vectors.xml" ]; then
	echo "#	$(date)	Unpacking Potlatch2 editor"
	tar xf ${websitesContentFolder}/edit/potlatchEditor.tgz -C ${websitesContentFolder}/edit/
	echo "#	$(date)	Completed installation of Potlatch2 editor"
    fi
fi

# Assume ownership of all the new files and folders
echo "#	Starting a series of recursive chown/chmod to set correct file ownership and permissions"
echo "#	chown -R ${username} ${websitesContentFolder}"
chown -R ${username} ${websitesContentFolder}
chown -R ${username} ${websitesLogsFolder}
chown -R ${username} ${websitesBackupsFolder}

# Add group writability
# This is necessary because although the umask is set correctly above (for the root user) the folder structure has been created via the Git clone/pull under ${asCS}
echo "#	chmod -R g+w ${websitesContentFolder}"
chmod -R g+w ${websitesContentFolder}
chmod -R g+w ${websitesLogsFolder}
chmod -R g+w ${websitesBackupsFolder}

# Create these log files to avoid them being created with root ownership when the routing service starts
touch ${websitesLogsFolder}/pythonAstarPort9000.log
chown ${username}:${rollout} ${websitesLogsFolder}/pythonAstarPort9000.log
touch ${websitesLogsFolder}/pythonAstarPort9000_status.log
chown ${username}:${rollout} ${websitesLogsFolder}/pythonAstarPort9000_status.log

# Allow the Apache webserver process to write / add to the data/ folder
echo "#	chown -R www-data ${websitesContentFolder}/data"
chown -R www-data ${websitesContentFolder}/data

# Select changelog
touch ${websitesContentFolder}/documentation/schema/selectChangeLog.sql
chown www-data:${rollout} ${websitesContentFolder}/documentation/schema/selectChangeLog.sql

# Requested missing cities logging (will disappear when ticket 645 cleared up)
touch ${websitesContentFolder}/documentation/RequestedMissingCities.tsv
chown www-data:${rollout} ${websitesContentFolder}/documentation/RequestedMissingCities.tsv

# Untemplatised pages logging
touch ${websitesContentFolder}/untemplatisedpages.txt
chown www-data:${rollout} ${websitesContentFolder}/untemplatisedpages.txt

# Tests autogeneration
chown www-data:${rollout} ${websitesContentFolder}/tests/

# VirtualHost configuration - for best compatibiliy use *.conf for the apache configuration files
csConf=cyclestreets.conf
csVirtualHostFile=/etc/apache2/sites-available/${csConf}
csSSLConf=
csSSLVirtualHostFile=
if [ -n "${useSSL}" ]; then
    csSSLConf=cyclestreets_ssl.conf
    csSSLVirtualHostFile=/etc/apache2/sites-available/${csSSLConf}

    # Copy SSL certs into apache folder
    cp -r ${useSSL} /etc/apache2/
fi

# Used to tune assertions directives in the virtualhosts if needed, initialize as empty.
phpAssertions=

# Controlling Assertions in PHP
# These comments relate to the setting of zend.assertions, mentioned in:
# https://www.php.net/manual/en/ini.core.php
# By default the value of this setting is 1 according to the manual, but in practice
# it comes up as -1 in fresh installations on Ubuntu 18.x and 20.x.
# This is an unusal setting in that if it is -1 or 1 it cannot be changed at runtime or by Apache configuration.
# The de facto default of -1 means that php code inside assert() code is not compiled, i.e. that assertions are ignored,
# and that PHP is running in a production mode.
# Therefore if a development mode is required this setting has to be changed to 0 or 1 in the php.ini system.
# The model used here is to set it to 0 in the php.ini via a cyclestreets.ini module, and then set it to 1 in the virtualhosts.
# Session lifetime settings are also included at this level as it has never worked having them in the Apache configuration.
if [ -n "${runtimePhpAssertions}" -o -n "${longerPhpSessions}" ]; then

    # Configure php with a .ini module having this name
    phpModule=cyclestreets

    # Get php version as e.g. 7.4
    phpMajorMinorVersion=$(php -v | grep -Po '(?<=PHP )([0-9].[0-9])')
    if [ -z "${phpMajorMinorVersion}" ]; then
	echo "# PHP configuration: Cannot determine the PHP version, abandoning the installation."
	exit 1
    fi

    # Write / replace the module file
    phpModulesPath=/etc/php/${phpMajorMinorVersion}/mods-available
    if [ ! -d $phpModulesPath ]; then
	echo "# PHP configuration: Cannot locate the modules directory expected at ${phpModulesPath}, abandoning the installation."
	exit 1
    fi
    phpConfigFile=${phpModulesPath}/${phpModule}.ini
    if [ -e  ${phpConfigFile} ]; then
	rm ${phpConfigFile}
    fi
    touch ${phpConfigFile}

    # Append assertions settings
    if [ -n "${runtimePhpAssertions}" ]; then
	cat >> ${phpConfigFile} <<EOF
[Assertion]
; Set to zero to permit runtime control of php assertions
zend.assertions = 0
EOF

	# The read can return non zero even though it has not errored so temporarily turn off stop on error
	set +e

	# Bind multi-line string for use in both main and api virtualhost configurations.
	# IFS is a special shell variable that stands for Internal Field Separator; look for it in man bash
	IFS='' read -r -d '' phpAssertions <<"EOF"

	# Assertions - turn on for development mode
	# Changing the first setting will only work when it has been initialized to 0 by the php.ini system.
	php_admin_value zend.assertions  1
EOF
	# Resume stop on error
	set -e

    fi

    # Append sessions settings
    if [ -n "${longerPhpSessions}" ]; then
	cat >> ${phpConfigFile} <<EOF
[Session]
; Php session - allow users to stay logged in to the website for up to 24 hours
session.gc_maxlifetime = 86400
session.cookie_lifetime = 86400
EOF
    fi

    # Activate the module
    # Note: Apache should be reloaded after this, but that happens later anyway
    phpenmod ${phpModule}
    echo "#	Enabled php module: ${phpModule}"

fi

# This variable is set when the hostname is localhost
usingLocalhost=
if [ "${csHostname}" = "localhost" ]; then
    usingLocalhost=1
fi

# This variable is set when the api uses the main hostname
apiSameHost=
if [ "${csHostname}" = "${apiHostname}" ]; then
    apiSameHost=1
fi

# Special case for localhost
locahostSpecialCase=
if [ -n "${usingLocalhost}" ]; then

    # The read can return non zero even though it has not errored so temporarily turn off stop on error
    set +e

    # Bind multi-line string for use in both main and api virtualhost configurations.
    # IFS is a special shell variable that stands for Internal Field Separator; look for it in man bash
    IFS='' read -r -d '' locahostSpecialCase <<"EOF"

	# This is necessary to enable cookies to work on the domain http://localhost/
	# http://stackoverflow.com/questions/1134290/cookies-on-localhost-with-explicit-domain
	php_admin_value session.cookie_domain none
EOF
	# Resume stop on error
	set -e
fi



# Redirect to https when SSL active
redirectHttps=
if [ -n "${useSSL}" ]; then

    # The read can return non zero even though it has not errored so temporarily turn off stop on error
    set +e

    # Bind multi-line string for use in both main and api virtualhost configurations.
    # IFS is a special shell variable that stands for Internal Field Separator; look for it in man bash
    IFS='' read -r -d '' redirectHttps <<"EOF"

	# Redirect all URLs to HTTPS, except API V1 calls
	RewriteEngine on
	RewriteCond %{REQUEST_URI} !^/api/([a-z]+)\.(xml|json)
	RewriteRule (.*) https://%{HTTP_HOST}%{REQUEST_URI} [L,R]

EOF
	# Resume stop on error
	set -e
fi


# Check if the VirtualHost exists already
if [ ! -r ${csVirtualHostFile} ]; then

    # When the api is the same as the hostname then include /v2/ redirects
    htaccessApi=
    if [ -n "${apiSameHost}" ]; then
	htaccessApi="Include /websites/www/content/.htaccess-api"
    fi

    # Create the VirtualHost (avoid any backquotes in the text as they will spawn sub-processes)
    cat > ${csVirtualHostFile} << EOF
<VirtualHost *:80>

	# Available URL(s)
	# Note: ServerName should not use wildcards; use ServerAlias for that.
	ServerName cyclestreets.net
	ServerAlias *.cyclestreets.net
	ServerAlias ${csHostname}

	# Logging
	CustomLog /websites/www/logs/${csHostname}-access.log combined
	ErrorLog /websites/www/logs/${csHostname}-error.log
${redirectHttps}
	# Where the files are
	DocumentRoot /websites/www/content/

	# Include the application routing and configuration directives, loading it into memory rather than forcing per-hit rescans
	Include /websites/www/content/.htaccess-base
	Include /websites/www/content/.htaccess-cyclestreets
	${htaccessApi}

${locahostSpecialCase}
${phpAssertions}
</VirtualHost>
EOF

    # Allow the user to edit this file
    chown ${username}:${rollout} ${csVirtualHostFile}

    # Enable this VirtualHost
    a2ensite ${csConf}

else
    echo "#	VirtualHost already exists: ${csVirtualHostFile}"
fi


# Same but for SSL version
# Check if the VirtualHost exists already
if [ -n "${useSSL}" -a -n "${csSSLVirtualHostFile}" ]; then
    if [ ! -r ${csSSLVirtualHostFile} ]; then

	# When the api is the same as the hostname then include /v2/ redirects
	htaccessApi=
	if [ -n "${apiSameHost}" ]; then
	    htaccessApi="Include /websites/www/content/.htaccess-api"
	fi

	# Create the SSL VirtualHost (avoid any backquotes in the text as they will spawn sub-processes)
	cat > ${csSSLVirtualHostFile} << EOF
<VirtualHost *:443>

	# Available URL(s)
	# Note: ServerName should not use wildcards; use ServerAlias for that.
	ServerName cyclestreets.net
	ServerAlias *.cyclestreets.net
	ServerAlias ${csHostname}

	# Logging
	CustomLog /websites/www/logs/${csHostname}_ssl-access.log combined
	ErrorLog /websites/www/logs/${csHostname}_ssl-error.log

	# Where the files are
	DocumentRoot /websites/www/content/

	# Include the application routing and configuration directives, loading it into memory rather than forcing per-hit rescans
	Include /websites/www/content/.htaccess-base
	Include /websites/www/content/.htaccess-cyclestreets
	${htaccessApi}

	# Certificates
	# http://billpatrianakos.me/blog/2014/04/04/installing-comodo-positive-ssl-certs-on-apache-and-openssl/
	SSLEngine on
	SSLCertificateFile      /etc/apache2/sslcerts/STAR_cyclestreets_net.crt
	SSLCertificateKeyFile   /etc/apache2/sslcerts/STAR_cyclestreets_net.key
	SSLCACertificateFile    /etc/apache2/sslcerts/STAR_cyclestreets_net.ca-bundle

${locahostSpecialCase}
${phpAssertions}
</VirtualHost>
EOF

	# Allow the user to edit this file
	chown ${username}:${rollout} ${csSSLVirtualHostFile}

	# Enable this VirtualHost
	a2ensite ${csSSLConf}

    else
	echo "#	SSL VirtualHost already exists: ${csSSLVirtualHostFile}"
    fi
fi


# Add the api address to /etc/hosts if it is not already present
echo "#	Checking entries on /etc/hosts"
if ! cat /etc/hosts | grep "\b${apiHostname}\b" > /dev/null 2>&1
then

    # Start a list of aliases to add
    aliases=${apiHostname}

    # Unless localhost is being used, check cs server name
    if [ -n "${usingLocalhost}" ]; then

	# If the servername is not present add an alias to localhost
	if  ! cat /etc/hosts | grep "\b${csHostname}\b" > /dev/null 2>&1
	then

	    # Add to aliases
	    aliases="${csHostname} ${aliases}"
	fi
    fi

    # Add aliases
    if [ -n "${aliases}" ]; then
	echo "#	Appending aliases for localhost: ${aliases}"
	sed -i -e "s/^127.0.0.1.*$/# Alias added by CycleStreets installation\n\0 ${aliases}/" /etc/hosts
    else
	echo "#	No cs or api hostname aliases added for localhost"
    fi
fi

# VirtualHost configuration - for best compatibiliy use *.conf for the apache configuration files
apiConf=api.cyclestreets.conf
apiVirtualHostFile=/etc/apache2/sites-available/${apiConf}
apiSSLConf=
apiSSLVirtualHostFile=
if [ -n "${useSSL}" ]; then
    apiSSLConf=api.cyclestreets_ssl.conf
    apiSSLVirtualHostFile=/etc/apache2/sites-available/${apiSSLConf}
fi


# Setup api virtualhost if distinct from main virtual host
# Also check if the api VirtualHost exists already
if [ -z "${apiSameHost}" -a ! -r ${apiVirtualHostFile} ]; then

	# Create the VirtualHost (avoid any backquotes in the text as they'll spawn sub-processes)
	cat > ${apiVirtualHostFile} << EOF
<VirtualHost *:80>

	# Available URL(s)
	# Note: ServerName should not use wildcards; use ServerAlias for that.
	ServerName api.cyclestreets.net
	ServerAlias ${apiHostname}

	# Logging
	CustomLog /websites/www/logs/${apiHostname}-access.log combined
	ErrorLog /websites/www/logs/${apiHostname}-error.log

	# Where the files are
	DocumentRoot /websites/www/content/

	# Include the application routing and configuration directives, loading it into memory rather than forcing per-hit
	Include /websites/www/content/.htaccess-base
	Include /websites/www/content/.htaccess-api

	# Development environment
	# Use MacroDevelopmentEnvironment '/'
</VirtualHost>
EOF

	# Allow the user to edit this file
	chown ${username}:${rollout} ${apiVirtualHostFile}

	# Enable this VirtualHost
	a2ensite ${apiConf}

else
    echo "#	API VirtualHost is not needed or already exists: ${apiVirtualHostFile}"
fi


# Same but for SSL version
# Check if the VirtualHost exists already
if [ -n "${useSSL}" -a -n "${apiSSLVirtualHostFile}" ]; then
    if [ -z "${apiSameHost}" -a ! -r "${apiSSLVirtualHostFile}" ]; then
	# Create the VirtualHost (avoid any backquotes in the text as they'll spawn sub-processes)
	cat > ${apiSSLVirtualHostFile} << EOF
<VirtualHost *:443>

	# Available URL(s)
	# Note: ServerName should not use wildcards; use ServerAlias for that.
	ServerName api.cyclestreets.net
	ServerAlias ${apiHostname}

	# Logging
	CustomLog /websites/www/logs/${apiHostname}_ssl-access.log combined
	ErrorLog /websites/www/logs/${apiHostname}_ssl-error.log

	# Where the files are
	DocumentRoot /websites/www/content/

	# Include the application routing and configuration directives, loading it into memory rather than forcing per-hit
	Include /websites/www/content/.htaccess-base
	Include /websites/www/content/.htaccess-api

	# Set a low-bandwidth error message for 404
	ErrorDocument 404 "404 https resource not found"

	# Certificates
	# http://billpatrianakos.me/blog/2014/04/04/installing-comodo-positive-ssl-certs-on-apache-and-openssl/
	SSLEngine on
	SSLCertificateFile      /etc/apache2/sslcerts/STAR_cyclestreets_net.crt
	SSLCertificateKeyFile   /etc/apache2/sslcerts/STAR_cyclestreets_net.key
	SSLCACertificateFile    /etc/apache2/sslcerts/STAR_cyclestreets_net.ca-bundle

	# Development environment
	# Use MacroDevelopmentEnvironment '/'
</VirtualHost>
EOF

	# Allow the user to edit this file
	chown ${username}:${rollout} ${apiSSLVirtualHostFile}

	# Enable this VirtualHost
	a2ensite ${apiSSLConf}
   else
       echo "#	API VirtualHost is not needed or already exists: ${apiVirtualHostFile}"
    fi
fi


# Global conf file
zcsGlobalConf=zcsglobal.conf

# Determine location of apache global configuration files
if [ -d /etc/apache2/conf-available ]; then
    # Apache 2.4 location
    globalApacheConfigFile=/etc/apache2/conf-available/${zcsGlobalConf}
elif [ -d /etc/apache2/conf.d ]; then
    # Apache 2.2 location
    globalApacheConfigFile=/etc/apache2/conf.d/${zcsGlobalConf}
else
    echo "#	Could not decide where to put global VirtualHost configuration"
    exit 1
fi

echo "#	Setting global VirtualHost configuration in ${globalApacheConfigFile}"

# Check if the local global apache config file exists already
if [ ! -r ${globalApacheConfigFile} ]; then
	
	# Copy in the global Apache config file
	cp -pr "${ScriptHome}/install-website/zcsglobal.conf" "${globalApacheConfigFile}"
	
	# Substitute in the Administrator e-mail
	sed -i -e "s/%administratorEmail/${administratorEmail}/" "${globalApacheConfigFile}"
else
	echo "#	Global apache configuration file already exists: ${globalApacheConfigFile}"
fi

# Enable the configuration file (only necessary in Apache 2.4)
if [ -d /etc/apache2/conf-available ]; then
    a2enconf ${zcsGlobalConf}
fi

# Reload apache
service apache2 reload

# Allow imports of collision data by permitting LOAD DATA
cp -pr "${DIR}/install-website/enable_local_infile.cnf" /etc/mysql/conf.d/
service mysql restart

# Useful binding
# The defaults-extra-file is a positional argument which must come first.
superMysql="mysql --defaults-extra-file=${mySuperCredFile} -hlocalhost"

# Create cyclestreets database
echo "# Create cyclestreets database"
${superMysql} -e "create database if not exists cyclestreets default character set utf8mb4 collate utf8mb4_unicode_ci;"

# Credentials for the website to access the database
mysqlWebsiteUsername=website
mysqlWebsitePassword=${password}

# Users are created by the grant command if they do not exist, making these idem potent.
# The grant is relative to localhost as it will be the apache server that authenticates against the local mysql.
${superMysql} -e "create user if not exists '${mysqlWebsiteUsername}'@'localhost' identified with mysql_native_password by '${mysqlWebsitePassword}';"
${superMysql} -e "grant select, insert, update, delete, create, execute, show view on cyclestreets.* to '${mysqlWebsiteUsername}'@'localhost';"
${superMysql} -e "grant select, execute, show view on \`routing%\` . * to '${mysqlWebsiteUsername}'@'localhost';"

# Allow the website to view any planetExtract files that have been created by an import
${superMysql} -e "grant select on \`planet%\` . * to '${mysqlWebsiteUsername}'@'localhost';"

# Create the settings file if it doesn't exist
phpConfig=".config.php"
if [ ! -e ${websitesContentFolder}/${phpConfig} ]
then
    # Make a copy from the config template
    cp -p .config.php.template ${phpConfig}
fi

# Include colon with internal port if set
hostPortwithColon=
if [ -n "${hostPort}" ]; then
    hostPortwithColon=:$hostPort

    # Accommodate port forwarding, redirecting http from hostport to guest port
    sudo iptables -t nat -I OUTPUT -p tcp -o lo --dport $hostPort -j REDIRECT --to-ports 80
fi

# Setup the configuration
if grep CONFIGURED_BY_HERE ${phpConfig} >/dev/null 2>&1;
then
    # Pre substitution

    # Developer site rewrites
    # Uses the value provided, else use a rewrite when the api is the same as main host so that api calls can find the right gui
    if [ -z "${devSiteRewrite}" -a -z "${apiSameHost}" ]; then
	devSiteRewrite="'YOUR_APISERVERNAME'				=> 'api.YOUR_CSSERVERNAME',"
    fi

    # Routing engine timeout (RETO)
    retoReplacement=
    if [ -n "${routingEngineTimeOut}" ]; then
	retoReplacement="\$config['routingEngineTimeOut']	= ${routingEngineTimeOut};"
    fi

    # Make the substitutions
    echo "#	Configuring the ${phpConfig}";
    # Substitutions that contains slashes are delimited by |.
    # The g modifier is used to perform a global match (find all matches rather than stopping after the first match).
    # It should be used when the substitution might occur more than once within the same line.
    sed -i \
	-e "s|CONFIGURED_BY_HERE|Configured by cyclestreets-setup $(date) for csHostname: ${csHostname}${sourceConfig}|" \
	-e "s/WEBSITE_USERNAME_HERE/${mysqlWebsiteUsername}/" \
	-e "s/WEBSITE_PASSWORD_HERE/${mysqlWebsitePassword}/" \
	-e "s/ADMIN_EMAIL_HERE/${administratorEmail}/" \
	-e "s/YOUR_EMAIL_HERE/${mainEmail}/" \
	-e "s/YOUR_SALT_HERE/${signinSalt}/" \
	-e "s/DEVSITEREWRITE/${devSiteRewrite}/" \
	-e "s/YOUR_CSSERVERNAME/${csHostname}/g" \
	-e "s/YOUR_APISERVERNAME/${apiHostname}/g" \
	-e "s/YOUR_HOSTPORT/${hostPortwithColon}/g" \
	-e "s|EXTRAAPIV2URLS|${extraApiV2urls}|" \
	-e "s|TESTS_ADDITIONAL_HERE|${testsAdditional}|" \
	-e "s|IMPORTCONTENTFOLDER_HERE|${importContentFolder}|" \
	-e "s/#YOUR_ROUTINGENGINETIMEOUT/${retoReplacement}/" \
	${phpConfig}
fi


# Data

# Install a basic cyclestreets db from the repository
# Unless the cyclestreets db has already been loaded (check for presence of map_config table)
if ! ${superMysql} --batch --skip-column-names -e "SHOW tables LIKE 'map_config'" cyclestreets | grep map_config  > /dev/null 2>&1
then
    # Load cyclestreets data
    echo "#	Load cyclestreets data"
    ${superMysql} cyclestreets < ${websitesContentFolder}/documentation/schema/sampleCycleStreets.sql

    # Set the database migration revison based on the creation data of the sample database file
    date -r ${websitesContentFolder}/documentation/schema/sampleCycleStreets.sql +%Y%m%d%H%M%S > ${websitesContentFolder}/data/dbmigrate.txt
    chown ${username}:${rollout} ${websitesContentFolder}/data/dbmigrate.txt


    # Set the API server
    apiTransport=http
    if [ -n "${useSSL}" ]; then
	apiTransport=https
    fi
    apiV2Url="${apiTransport}://${apiHostname}${hostPortwithColon}/v2/"
    ${superMysql} cyclestreets -e "update map_config set routeServerUrl='http://${csHostname}:9000/', apiV2Url='${apiV2Url}' where id = 1;"

    # Set the gui server
    # #!# This needs review - on one live machine it is set as localhost and always ignored
    ${superMysql} cyclestreets -e "update map_gui set server='${csHostname}' where id = 1;"

    # Only the main www site needs city-specific urls, this turns them off for general installations
    ${superMysql} cyclestreets -e "update map_gui set cityId = 0 where id = 1;"

    # Set an internal api key
    ${superMysql} cyclestreets -e "update map_gui set internalApikey=lower(hex(random_bytes(8))) where id = 1;"
    ${superMysql} cyclestreets -e "insert map_apikeys (id, service, type, apiKey, userid, notes) values (1, 'CycleStreets Service', 'Desktop', '0123456789abcdef', 0, '');"
    ${superMysql} cyclestreets -e "update map_apikeys set approved = 1 where id = 1;"
    ${superMysql} cyclestreets -e "update map_apikeys set apiKey = (select internalApikey from map_gui where id = 1) where id = 1;"

    # Tests API key
    ${superMysql} cyclestreets -e "insert map_apikeys (id, service, type, apiKey, userid, notes, approved) values (2, 'Sample API calls from /api/ webpage', 'Both', '${testsApiKey}', 1, '', 1);"

    # Create an admin user
    # Use a validatedAt that is a day old to avoid notification of new users from pseudoCron.
    encryption=`php -r"echo password_hash('${password}', PASSWORD_DEFAULT);"`
    ${superMysql} cyclestreets -e "insert user_user (username, email, password, privileges, validatedAt, createdAt) values ('${username}', '${administratorEmail}', '${encryption}', 'administrator', date_sub(now(), interval 1 day), NOW());"

    # Create a welcome tinkle
    ${superMysql} cyclestreets -e "insert tinkle (userId, tinkle) values (1, 'Welcome to CycleStreets');"

    # Initialize pseudoCron
    ${superMysql} cyclestreets -e "update map_config set pseudoCron = DATE_SUB(CURDATE(), INTERVAL 1 DAY) WHERE id = 1;"
fi

# Unless the database already exists:
if ! ${superMysql} --batch --skip-column-names -e "SHOW DATABASES LIKE '${archiveDb}'" | grep ${archiveDb} > /dev/null 2>&1
then
    # Create archive database
    echo "#	Create ${archiveDb} database"
    ${superMysql} < ${websitesContentFolder}/documentation/schema/csArchive.sql

    # Allow website read only access
    ${superMysql} -e "grant select on \`${archiveDb}\` . * to '${mysqlWebsiteUsername}'@'localhost';"
fi

# External db
if [ -n "${externalDb}" ]; then

    # Does the database already exist?
    xdbPreExists=$(${superMysql} --batch --skip-column-names -e "SHOW DATABASES LIKE '${externalDb}'")

    # This creates only a skeleton and sets up grant permissions.
    if [ -z "${xdbPreExists}" ]; then

	# Create external database
	echo "#	Create ${externalDb} database"
	echo "#	Note: contains table definitions only and no data - a full version is downloaded next."
	${superMysql} < ${websitesContentFolder}/documentation/schema/csExternal.sql

	# Allow website read only access
	${superMysql} -e "grant select on \`${externalDb}\` . * to '${mysqlWebsiteUsername}'@'localhost';"
    fi

    # Useful binding
    csExternalDataFile=csExternal.sql.gz

    # External db restore - if it doesn't pre-exist
    if [ -z "${xdbPreExists}" -a -n "${csExternalDataFile}" -a ! -e /tmp/${csExternalDataFile} ]; then

	# Report
	echo "#	$(date)	Starting download of external database"

	# Download
	wget https://cyclestreets:${datapassword}@downloads.cyclestreets.net/${csExternalDataFile} -O /tmp/${csExternalDataFile}

	# Report
	echo "#	$(date)	Starting installation of external database"

	# Unpack into the skeleton db
	gunzip < /tmp/${csExternalDataFile} | ${superMysql} ${externalDb}

	# Remove the archive to save space
	rm /tmp/${csExternalDataFile}

	# Report
	echo "#	$(date)	Completed installation of external database"
    fi
fi

# Batch db
# This creates only a skeleton and sets up grant permissions. A full installation is not yet available.
# Unless the database already exists:
if [ -n "${batchDb}" ] && ! ${superMysql} --batch --skip-column-names -e "SHOW DATABASES LIKE '${batchDb}'" | grep ${batchDb} > /dev/null 2>&1 ; then

    # Create batch database
    echo "#	Create ${batchDb} database"
    ${superMysql} -e "create database if not exists ${batchDb} default character set utf8mb4 collate utf8mb4_unicode_ci;"

    # Grants; note that the FILE privilege (which is not database-specific) is required so that table contents can be loaded from a file
    ${superMysql} -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, LOCK TABLES, CREATE VIEW on \`${batchDb}\` . * to '${mysqlWebsiteUsername}'@'localhost';"
    ${superMysql} -e "GRANT FILE ON *.* TO '${mysqlWebsiteUsername}'@'localhost';"

    echo "#	Note: this contains table definitions only and contains no data."
    ${superMysql} < ${websitesContentFolder}/documentation/schema/csBatch.sql
fi

# Identify the sample database (the -s suppresses the tabular output)
sampleRoutingDb=$(${superMysql} -s cyclestreets<<<"select routingDb from map_config limit 1")
echo "#	The sample database is: ${sampleRoutingDb}"

# Unless the sample routing database already exists:
if ! ${superMysql} --batch --skip-column-names -e "SHOW DATABASES LIKE '${sampleRoutingDb}'" | grep ${sampleRoutingDb} > /dev/null 2>&1
then
    # Create sampleRoutingDb database
    echo "#	Create ${sampleRoutingDb} database"
    ${superMysql} -e "create database if not exists ${sampleRoutingDb} default character set utf8mb4 collate utf8mb4_unicode_ci;"

    # Load data
    echo "#	Load ${sampleRoutingDb} data"
    gunzip < ${websitesContentFolder}/documentation/schema/sampleRouting.sql.gz | ${superMysql} ${sampleRoutingDb}
fi

# Unless the sample routing data exists:
if [ ! -d ${websitesContentFolder}/data/routing/${sampleRoutingDb} ]; then
    echo "#	Unpacking ${sampleRoutingDb} data"
    tar xf ${websitesContentFolder}/documentation/schema/sampleRoutingData.tar.gz -C ${websitesContentFolder}/data/routing
fi


# Routing service configuration if not already present
routingEngineConfigFile=${websitesContentFolder}/routingengine/.config.json
if [ ! -L $routingEngineConfigFile ]; then
	# Link to the JSON config for the basic routing db, as cyclestreets user
	${asCS} ln -s ${websitesContentFolder}/data/routing/${sampleRoutingDb}/.config.json $routingEngineConfigFile
fi

# Compile the C++ module; see: https://github.com/cyclestreets/cyclestreets/wiki/Python-routing---starting-and-monitoring
sudo apt -y install gcc g++ python3-dev make cmake doxygen graphviz
if [ ! -e ${websitesContentFolder}/routingengine/astar_impl.so ]; then
	echo "Building CycleStreets routing C++ module..."
	cd "${websitesContentFolder}/routingengine/"
	${asCS} ./buildre.sh
	cd ${websitesContentFolder}
fi

# Add Exim, so that mail will be sent, and add its configuration, but firstly backing up the original exim distribution config file if not already done
# NB The config here is currently Debian/Ubuntu-specific
sudo apt -y install exim4
if [ ! -e /etc/exim4/update-exim4.conf.conf.original ]; then
    cp -pr /etc/exim4/update-exim4.conf.conf /etc/exim4/update-exim4.conf.conf.original
fi
# NB These will deliberately overwrite any existing config; it is assumed that once set, the config will only be changed via this setup script (as otherwise it is painful during testing)
sed -i "s/dc_eximconfig_configtype=.*/dc_eximconfig_configtype='${dc_eximconfig_configtype}'/" /etc/exim4/update-exim4.conf.conf
sed -i "s/dc_local_interfaces=.*/dc_local_interfaces='${dc_local_interfaces}'/" /etc/exim4/update-exim4.conf.conf
sed -i "s/dc_readhost=.*/dc_readhost='${dc_readhost}'/" /etc/exim4/update-exim4.conf.conf
sed -i "s/dc_smarthost=.*/dc_smarthost='${dc_smarthost}'/" /etc/exim4/update-exim4.conf.conf
# NB These two are the same in any CycleStreets installation but different from the default Debian installation:
sed -i "s/dc_other_hostnames=.*/dc_other_hostnames=''/" /etc/exim4/update-exim4.conf.conf
sed -i "s/dc_hide_mailname=.*/dc_hide_mailname='true'/" /etc/exim4/update-exim4.conf.conf
sudo systemctl restart exim4


# Install the cycle routing service

# Setup a symlink from the systemd folder, if it doesn't already exist
routingServiceLocation=/etc/systemd/system/cyclestreets.service
if [ ! -L ${routingServiceLocation} ]; then
    ln -s ${websitesContentFolder}/routingengine/cyclestreets.service ${routingServiceLocation}
fi

# Ensure the relevant files are executable
chmod ug+x ${websitesContentFolder}/routingengine/cyclestreets.py

# Check the local routing service
# The status check produces an error if it is not running, so briefly turn off abandon-on-error to catch and report the problem.
set +e

# Get the status
localRoutingStatus=$(systemctl status cyclestreets)
# If it is not running an error value (ie not zero) is returned
if [ $? -ne 0 ]; then
    # Start the service (using command that matches pattern setup in passwordless sudo)
    sudo /bin/systemctl start cyclestreets
    echo -e "\n# Follow the routing log using: tail -f ${websitesLogsFolder}/pythonAstarPort9000.log"
fi
# Restore abandon-on-error
set -e

# Add the service to the system initialization, so that it will start on reboot
sudo systemctl enable cyclestreets

# Advise setting up
if [ -n "${usingLocalhost}" ]; then
    echo "#	Ensure ${csHostname} routes to this machine, eg by adding this line to /etc/hosts"
    echo "127.0.0.1	${csHostname} ${apiHostname}"
fi

# Announce end of script
echo "#	CycleStreets installed $(date), visit http://${csHostname}${hostPortwithColon}/"

# Return true to indicate success
:

# End of file
