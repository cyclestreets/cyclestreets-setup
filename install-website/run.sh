#!/bin/bash
# Script to install CycleStreets on Ubuntu
# Written for Ubuntu Server 16.04 LTS (View Ubuntu version using 'lsb_release -a')
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
echo "#	Installing CycleStreets website for base OS: ${baseOS}"

# Install a base webserver machine with webserver software (Apache, PHP, MySQL), relevant users and main directory
. ${ScriptHome}/utility/installBaseWebserver.sh

# Load common install script
. ${ScriptHome}/utility/installCommon.sh

# Ensure JSON support
apt-get -y install php-json

# Ensure Zip support (e.g. for multiple photomap uploads)
apt-get -y install php7.2-zip

# ImageMagick is used to provide enhanced maplet drawing. It is optional - if not present gd is used instead.
apt-get -y install imagemagick php-imagick

# Enable mod_deflate for Apache
sudo a2enmod deflate
service apache2 restart

# Install Python
echo "#	Installing python"
apt-get -y install python php-xmlrpc php-curl

# Utilities
echo "#	Some utilities"

# ffmpeg; this has been restored in 16.04 as an official package
apt-get -y install ffmpeg

# Install Apache mod_macro for convenience (not an actual requirement for CycleStreets - maybe was needed with ffmpeg?)
# apt-get -y install libapache2-mod-macro

# Install NTP to keep the clock correct (e.g. to avoid wrong GPS synchronisation timings)
apt-get -y install ntp

# These are used by deployment scripts to correspond with the routing servers via xml
apt-get -y install curl libxml-xpath-perl


# Geolocation by synchronization
# https://github.com/cyclestreets/cyclestreets/wiki/GPS-Syncronization
# For gpsPhoto.pl, add dependencies
apt-get -y install libimage-exiftool-perl
# This one might not actually be needed
apt-get -y install libxml-dom-perl

# HTML to PDF conversion
# http://wkhtmltopdf.org/downloads.html
# Note: using "apt-get -y install wkhtmltopdf" gives version 0.9.9 which has the "cannot connect to X server" problem; apparently this is fixed in 0.12
# See: http://stackoverflow.com/questions/9604625/wkhtmltopdf-cannot-connect-to-x-server
# See: http://xfloyd.net/blog/?p=745
apt-get -y install xfonts-75dpi wkhtmltopdf
# On Mac OSX, use the following as documented at http://stackoverflow.com/a/14043085/180733 and https://gist.github.com/semanticart/389944e2bcdba5424e01
# brew install https://gist.githubusercontent.com/semanticart/389944e2bcdba5424e01/raw/9ed120477b57daf10d7de6d585d49b2017cd6955/wkhtmltopdf.rb


# Install Potlatch editor
#!# This currently assumes the existence of the .tgz file; need to make this part of a repo at some point
#!# Ideally we would:
#    1) Pull down the latest dev code from https://github.com/openstreetmap/potlatch2
#    2) Compile using Flex as detailed in the README, using the Flex install instructions at http://thomas.deuling.org/2011/05/install-flex-sdk-under-ubuntu-linux/
#    3) Add in the local config, which are believed to be map_features.xml (position of transport block moved) and vectors.xml (which defines the external sources); possibly there are other files - needs to be checked
potlatchEditorFile=potlatchEditor.tgz

# Check if there is a password for the data store and that the file has not already been obtained
if [ -n "${datapassword}" -a ! -e ${websitesBackupsFolder}/${potlatchEditorFile} ]; then

	# Report
	echo "#	$(date)	Starting download of potlatch editor"

	# Download
	wget https://cyclestreets:${datapassword}@downloads.cyclestreets.net/${potlatchEditorFile} -O ${websitesBackupsFolder}/${potlatchEditorFile}

	# Report
	echo "#	$(date)	Starting installation of potlatch editor"

	# Unpack
	tar xf ${websitesBackupsFolder}/potlatchEditor.tgz -C ${websitesContentFolder}/edit

	# Report
	echo "#	$(date)	Completed installation of potlatch editor"
fi

# Assume ownership of all the new files and folders
echo "#	Starting a series of recursive chown/chmod to set correct file ownership and permissions"
echo "#	chown -R ${username} ${websitesContentFolder}"
chown -R ${username} ${websitesContentFolder}
chown -R ${username} ${websitesLogsFolder}
chown -R ${username} ${websitesBackupsFolder}

# Add group writability
# This is necessary because although the umask is set correctly above (for the root user) the folder structure has been created via the svn co/update under ${asCS}
echo "#	chmod -R g+w ${websitesContentFolder}"
chmod -R g+w ${websitesContentFolder}
chmod -R g+w ${websitesLogsFolder}
chmod -R g+w ${websitesBackupsFolder}

# Ensure the webserver (and group, but not others ideally) have executability on gpsPhoto.pl
chown www-data ${websitesContentFolder}/libraries/gpsPhoto.pl
chmod -x ${websitesContentFolder}/libraries/gpsPhoto.pl
chmod ug+x ${websitesContentFolder}/libraries/gpsPhoto.pl

# Allow the Apache webserver process to write / add to the data/ folder
echo "#	chown -R www-data ${websitesContentFolder}/data"
chown -R www-data ${websitesContentFolder}/data

# Select changelog
touch ${websitesContentFolder}/documentation/schema/selectChangeLog.sql
chown www-data:${rollout} ${websitesContentFolder}/documentation/schema/selectChangeLog.sql

# Requested missing cities logging (will disappear when ticket 645 cleared up)
touch ${websitesContentFolder}/documentation/RequestedMissingCities.tsv
chown www-data:${rollout} ${websitesContentFolder}/documentation/RequestedMissingCities.tsv

# Tests autogeneration
chown www-data:${rollout} ${websitesContentFolder}/tests/

# VirtualHost configuration - for best compatibiliy use *.conf for the apache configuration files
cslocalconf=cyclestreets.conf
localVirtualHostFile=/etc/apache2/sites-available/${cslocalconf}

# Check if the local VirtualHost exists already
if [ ! -r ${localVirtualHostFile} ]; then
    # Create the local VirtualHost (avoid any backquotes in the text as they will spawn sub-processes)
    cat > ${localVirtualHostFile} << EOF
<VirtualHost *:80>
	
	# Available URL(s)
	# Note: ServerName should not use wildcards; use ServerAlias for that.
	ServerName cyclestreets.net
	ServerAlias *.cyclestreets.net
	ServerAlias ${csHostname}
	
	# Logging
	CustomLog /websites/www/logs/cyclestreets.net-access.log combined
	ErrorLog /websites/www/logs/cyclestreets.net-error.log
	
	# Where the files are
	DocumentRoot /websites/www/content/
	
	# Include the application routing and configuration directives, loading it into memory rather than forcing per-hit rescans
	Include /websites/www/content/.htaccess-base
	Include /websites/www/content/.htaccess-cyclestreets
	
	# This is necessary to enable cookies to work on the domain http://localhost/
	# http://stackoverflow.com/questions/1134290/cookies-on-localhost-with-explicit-domain
	php_admin_value session.cookie_domain none
	
</VirtualHost>
EOF

    # Allow the user to edit this file
    chown ${username}:${rollout} ${localVirtualHostFile}

else
    echo "#	VirtualHost already exists: ${localVirtualHostFile}"
fi

# Enable this VirtualHost
a2ensite ${cslocalconf}

# Add the api address to /etc/hosts if it is not already present
if ! cat /etc/hosts | grep "\b${apiHostname}\b" > /dev/null 2>&1
then

    # Start a list of aliases to add
    aliases=${apiHostname}

    # Unless localhost is being used, check cs server name
    if [ "${csHostname}" != "localhost" ]; then

	# If the servername is not present add an alias to localhost
	if  ! cat /etc/hosts | grep "\b${csHostname}\b" > /dev/null 2>&1
	then

	    # Add to aliases
	    aliases="${csHostname} ${aliases}"
	fi
    fi

    # Append
    echo "# Added by CycleStreets installation" >> /etc/hosts
    echo "127.0.1.1	${aliases}" >> /etc/hosts
fi

# VirtualHost configuration - for best compatibiliy use *.conf for the apache configuration files
apilocalconf=api.cyclestreets.conf
apiLocalVirtualHostFile=/etc/apache2/sites-available/${apilocalconf}

# Check if the local VirtualHost exists already
if [ ! -r ${apiLocalVirtualHostFile} ]; then
    # Create the local VirtualHost (avoid any backquotes in the text as they'll spawn sub-processes)
    cat > ${apiLocalVirtualHostFile} << EOF
<VirtualHost *:80>

	ServerName ${apiHostname}
	
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
    chown ${username}:${rollout} ${apiLocalVirtualHostFile}

else
    echo "#	VirtualHost already exists: ${apiLocalVirtualHostFile}"
fi

# Enable this VirtualHost
a2ensite ${apilocalconf}



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

# Create cyclestreets database
${superMysql} -e "create database if not exists cyclestreets default character set utf8 collate utf8_unicode_ci;"

# Users are created by the grant command if they do not exist, making these idem potent.
# The grant is relative to localhost as it will be the apache server that authenticates against the local mysql.
${superMysql} -e "grant select, insert, update, delete, create, execute on cyclestreets.* to '${mysqlWebsiteUsername}'@'localhost' identified by '${mysqlWebsitePassword}';"
${superMysql} -e "grant select, execute on \`routing%\` . * to '${mysqlWebsiteUsername}'@'localhost';"

# Allow the website to view any planetExtract files that have been created by an import
${superMysql} -e "grant select on \`planetExtractOSM%\` . * to '${mysqlWebsiteUsername}'@'localhost';"

# Create the settings file if it doesn't exist
phpConfig=".config.php"
if [ ! -e ${websitesContentFolder}/${phpConfig} ]
then
    # Make a copy from the config template
    cp -p .config.php.template ${phpConfig}
fi

# Setup the configuration
if grep CONFIGURED_BY_HERE ${phpConfig} >/dev/null 2>&1;
then

    # Make the substitutions
    echo "#	Configuring the ${phpConfig}";
    sed -i \
-e "s|CONFIGURED_BY_HERE|Configured by cyclestreets-setup for csHostname: ${csHostname}${sourceConfig}|" \
-e "s/WEBSITE_USERNAME_HERE/${mysqlWebsiteUsername}/" \
-e "s/WEBSITE_PASSWORD_HERE/${mysqlWebsitePassword}/" \
-e "s/ADMIN_EMAIL_HERE/${administratorEmail}/" \
-e "s/YOUR_EMAIL_HERE/${mainEmail}/" \
-e "s/YOUR_SALT_HERE/${signinSalt}/" \
-e "s/YOUR_CSSERVERNAME/${csHostname}/g" \
-e "s/YOUR_APISERVERNAME/${apiHostname}/g" \
	${phpConfig}
fi


# Data

# Install a basic cyclestreets db from the repository
# Unless the cyclestreets db has already been loaded (check for presence of map_config table)
if ! ${superMysql} --batch --skip-column-names -e "SHOW tables LIKE 'map_config'" cyclestreets | grep map_config  > /dev/null 2>&1
then
    # Load cyclestreets data
    echo "#	Load cyclestreets data"
    ${superMysql} cyclestreets < ${websitesContentFolder}/documentation/schema/sampleCyclestreets.sql

    # Set the API server
    # Uses http rather than https as that will help get it working, then user can change later via the control panel.
    ${superMysql} cyclestreets -e "update map_config set routeServerUrl='http://${csHostname}:9000/', apiV2Url='http://${apiHostname}/v2/' where id = 1;"

    # Set the gui server
    # #!# This needs review - on one live machine it is set as localhost and always ignored
    ${superMysql} cyclestreets -e "update map_gui set server='${csHostname}' where id = 1;"

    # Create an admin user
    encryption=`php -r"echo password_hash('${password}', PASSWORD_DEFAULT);"`
    ${superMysql} cyclestreets -e "insert user_user (username, email, password, privileges, validatedAt, createdAt) values ('${username}', '${administratorEmail}', '${encryption}', 'administrator', NOW(), NOW());"

    # Create a welcome tinkle
    ${superMysql} cyclestreets -e "insert tinkle (userId, tinkle) values (1, 'Welcome to CycleStreets');"

    # Initialize pseudoCron
    ${superMysql} cyclestreets -e "update map_config set pseudoCron = DATE_SUB(CURDATE(), INTERVAL 1 DAY) WHERE id = 1;"
fi

# Archive db
archiveDb=csArchive
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
# This creates only a skeleton and sets up grant permissions. The full installation is done by a script in install-import folder.
# Unless the database already exists:
if [ -n "${externalDb}" ] && ! ${superMysql} --batch --skip-column-names -e "SHOW DATABASES LIKE '${externalDb}'" | grep ${externalDb} > /dev/null 2>&1
then

    # Create external database
    echo "#	Create ${externalDb} database"
    echo "#	Note: this contains table definitions only and contains no data. A full version must be downloaded separately see ../install-import/run.sh"
    ${superMysql} < ${websitesContentFolder}/documentation/schema/csExternal.sql

    # Allow website read only access
    ${superMysql} -e "grant select on \`${externalDb}\` . * to '${mysqlWebsiteUsername}'@'localhost';"
fi

# File to avoid re-download of the csExternalDataFile
csExternalDataFileDownloaded=${websitesBackupsFolder}/csExternalDataFileDownloaded.txt

# External db restore
if [ -n "${externalDb}" -a -n "${csExternalDataFile}" -a ! -e ${websitesBackupsFolder}/${csExternalDataFile} -a ! -e ${csExternalDataFileDownloaded} ]; then

	# Report
	echo "#	$(date)	Starting download of external database"

	# Download
	wget https://cyclestreets:${datapassword}@downloads.cyclestreets.net/${csExternalDataFile} -O ${websitesBackupsFolder}/${csExternalDataFile}

	# Report
	echo "#	$(date)	Starting installation of external database"

	# Unpack into the skeleton db
	gunzip < ${websitesBackupsFolder}/${csExternalDataFile} | ${superMysql} ${externalDb}

	# Remove the archive to save space
	rm ${websitesBackupsFolder}/${csExternalDataFile}

	# Create an empty file to avoid re-download
	cat > ${csExternalDataFileDownloaded} <<EOF
Created by cyclestreets-setup/install-website/run.sh
This file exists to avoid a re-download of the csExternalDataFile.
EOF

	# Report
	echo "#	$(date)	Completed installation of external database"
fi

# Batch db
# This creates only a skeleton and sets up grant permissions. A full installation is not yet available.
# Unless the database already exists:
if [ -n "${batchDb}" ] && ! ${superMysql} --batch --skip-column-names -e "SHOW DATABASES LIKE '${batchDb}'" | grep ${batchDb} > /dev/null 2>&1 ; then

    # Create batch database
    echo "#	Create ${batchDb} database"
    ${superMysql} -e "create database if not exists ${batchDb} default character set utf8 collate utf8_unicode_ci;"

    # Grants; note that the FILE privilege (which is not database-specific) is required so that table contents can be loaded from a file
    ${superMysql} -e "GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, LOCK TABLES on \`${batchDb}\` . * to '${mysqlWebsiteUsername}'@'localhost';"
    ${superMysql} -e "GRANT FILE ON *.* TO '${mysqlWebsiteUsername}'@'localhost';"

    echo "#	Note: this contains table definitions only and contains no data."
    ${superMysql} < ${websitesContentFolder}/documentation/schema/csBatch.sql
    
else
    echo "#	Skipping batch database"
fi

# Identify the sample database (the -s suppresses the tabular output)
sampleRoutingDb=$(${superMysql} -s cyclestreets<<<"select routingDb from map_config limit 1")
echo "#	The sample database is: ${sampleRoutingDb}"

# Unless the sample routing database already exists:
if ! ${superMysql} --batch --skip-column-names -e "SHOW DATABASES LIKE '${sampleRoutingDb}'" | grep ${sampleRoutingDb} > /dev/null 2>&1
then
    # Create sampleRoutingDb database
    echo "#	Create ${sampleRoutingDb} database"
    ${superMysql} -e "create database if not exists ${sampleRoutingDb} default character set utf8 collate utf8_unicode_ci;"

    # Load data
    echo "#	Load ${sampleRoutingDb} data"
    gunzip < ${websitesContentFolder}/documentation/schema/sampleRouting.sql.gz | ${superMysql} ${sampleRoutingDb}
fi

# Unless the sample routing data exists:
if [ ! -d ${websitesContentFolder}/data/routing/${sampleRoutingDb} ]; then
    echo "#	Unpacking ${sampleRoutingDb} data"
    tar xf ${websitesContentFolder}/documentation/schema/sampleRoutingData.tar.gz -C ${websitesContentFolder}/data/routing
fi


# Create a config if not already present
if [ ! -x "${routingEngineConfigFile}" ]; then
	# Create the config for the basic routing db, as cyclestreets user
	${asCS} touch "${routingEngineConfigFile}"
	${asCS} echo -e "#!/bin/bash\nBASEDIR=${websitesContentFolder}/data/routing/${sampleRoutingDb}" > "${routingEngineConfigFile}"
	# Ensure it is executable
	chmod a+x "${routingEngineConfigFile}"
fi

# Compile the C++ module; see: https://github.com/cyclestreets/cyclestreets/wiki/Python-routing---starting-and-monitoring
sudo apt-get -y install gcc g++ python-dev make cmake doxygen graphviz
if [ ! -e ${websitesContentFolder}/routingengine/astar_impl.so ]; then
	echo "Now building the C++ routing module..."
	cd "${websitesContentFolder}/routingengine/"
	${asCS} ./buildre.sh
	cd ${websitesContentFolder}
fi

# Add this python module which is needed by the routing service
sudo apt-get -y install python-argparse

# Add Exim, so that mail will be sent, and add its configuration, but firstly backing up the original exim distribution config file if not already done
if $configureExim ; then
    # NB The config here is currently Debian/Ubuntu-specific
    sudo apt-get -y install exim4
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
    sudo service exim4 restart
fi

# Install the cycle routing daemon (service)
if $installRoutingAsDaemon ; then

    # Setup a symlink from the etc init demons folder, if it doesn't already exist
    if [ ! -L ${routingDaemonLocation} ]; then
	ln -s ${websitesContentFolder}/routingengine/cyclerouting.init.d ${routingDaemonLocation}
    fi

    # Ensure the relevant files are executable
    chmod ug+x ${websitesContentFolder}/routingengine/cyclerouting.init.d
    chmod ug+x ${websitesContentFolder}/routingengine/server.py

    # Check the local routing service
    # The status check produces an error if it is not running, so briefly turn off abandon-on-error to catch and report the problem.
    set +e
    # Get the status
    localRoutingStatus=$(${routingDaemonLocation} status)
    # If it is not running an error value (ie not zero) is returned
    if [ $? -ne 0 ]
    then
	# Start the service
	${routingDaemonStart}
	echo -e "\n# Follow the routing log using: tail -f ${websitesLogsFolder}/pythonAstarPort9000.log"
    fi
    # Restore abandon-on-error
    set -e


    # Add the daemon to the system initialization, so that it will start on reboot
    update-rc.d cycleroutingd defaults

else

    echo "#	Routing service - (not installed as a daemon)"
    echo "#	Can be manually started from the command line using:"
    echo "#	sudo -u cyclestreets ${websitesContentFolder}/routingengine/server.py"

    # If it was previously setup as a daemon, remove it
    if [ -L ${routingDaemonLocation} ]; then

	# Ensure it is stopped
	${routingDaemonStop}

	# Remove the symlink
	rm ${routingDaemonLocation}

	# Remove the daemon from the system initialization
	update-rc.d cycleroutingd remove
    fi

fi



# Advise setting up
if [ "${csHostname}" != "localhost" ]; then
    echo "#	Ensure ${csHostname} routes to this machine, eg by adding this line to /etc/hosts"
    echo "127.0.0.1	${csHostname} ${apiHostname}"
fi

# Announce end of script
echo "#	CycleStreets installed $(date), visit http://${csHostname}/"

# Return true to indicate success
:

# End of file
