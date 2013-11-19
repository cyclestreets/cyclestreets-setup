#!/bin/bash
# Script to install CycleStreets on Ubuntu
# Tested on 12.10 (View Ubuntu version using 'lsb_release -a')
# This script is idempotent - it can be safely re-run without destroying existing data

echo "#	CycleStreets installation $(date)"

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
echo "#	CycleStreets installation in progress, follow log file with: tail -f ${setupLogFile}"
echo "#	CycleStreets installation $(date)" >> ${setupLogFile}

# Ensure there is a cyclestreets user account
if id -u ${username} >/dev/null 2>&1; then
    echo "#	User ${username} exists already and will be used."
else
    echo "#	User ${username} does not exist: creating now."

    # Request a password for the CycleStreets user account; see http://stackoverflow.com/questions/3980668/how-to-get-a-password-from-a-shell-script-without-echoing
    if [ ! ${password} ]; then
	stty -echo
	printf "Please enter a password that will be used to create the CycleStreets user account:"
	read password
	printf "\n"
	printf "Confirm that password:"
	read passwordconfirm
	printf "\n"
	stty echo
	if [ $password != $passwordconfirm ]; then
	    echo "#	The passwords did not match"
	    exit 1
	fi
    fi

    # Create the CycleStreets user
    useradd -m $username >> ${setupLogFile}
    # Assign the password - this technique hides it from process listings
    echo "${username}:${password}" | /usr/sbin/chpasswd
    echo "#	CycleStreets user ${username} created" >> ${setupLogFile}
fi

# Add the user to the sudo group, if they are not already present
if ! groups ${username} | grep "\bsudo\b" > /dev/null 2>&1
then
    adduser ${username} sudo
fi

# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Prepare the apt index; it may be practically non-existent on a fresh VM
apt-get update > /dev/null

# Install basic software
apt-get -y install wget git emacs >> ${setupLogFile}

# Install Apache, PHP
echo "#	Installing Apache, MySQL, PHP" >> ${setupLogFile}

is_installed () {
	dpkg -s "$1" | grep -q '^Status:.*installed'
}

# Provide the mysql root password - to avoid being prompted.
if [ -z "${mysqlRootPassword}" ] && ! is_installed mysql-server ; then
	echo "# You have apparently not specified a MySQL root password"
	echo "# This means the install script would get stuck prompting for one"
	echo "# .. aborting"
	exit 1
fi

echo mysql-server mysql-server/root_password password ${mysqlRootPassword} | debconf-set-selections
echo mysql-server mysql-server/root_password_again password ${mysqlRootPassword} | debconf-set-selections

# Install core webserver software
echo "#	Installing core webserver packages" >> ${setupLogFile}
apt-get -y install apache2 mysql-server mysql-client php5 php5-gd php5-cli php5-mysql >> ${setupLogFile}

# Note: some new versions of php5.5 are missing json functions. This can be easily remedied by including the package: php5-json

# ImageMagick is used to provide enhanced maplet drawing. It is optional - if not present gd is used instead.
apt-get -y install imagemagick php5-imagick >> ${setupLogFile}

# Apache/PHP performance packages (mod_deflate for Apache, APC cache for PHP)
sudo a2enmod deflate
apt-get -y install php-apc >> ${setupLogFile}
service apache2 restart

# Install Python
echo "#	Installing python" >> ${setupLogFile}
apt-get -y install python php5-xmlrpc php5-curl >> ${setupLogFile}

# Utilities
echo "#	Some utilities" >> ${setupLogFile}
apt-get -y install subversion openjdk-6-jre bzip2 ffmpeg >> ${setupLogFile}

# Install NTP to keep the clock correct (e.g. to avoid wrong GPS synchronisation timings)
apt-get -y install ntp >> ${setupLogFile}

# This package prompts for configuration, and so is left out of this script as it is only a developer tool which can be installed later.
# apt-get -y install phpmyadmin

# Determine the current actual user
currentActualUser=`who am i | awk '{print $1}'`

# Create the rollout group, if it does not already exist
#!# The group name should be a setting
if ! grep -i "^rollout\b" /etc/group > /dev/null 2>&1
then
    addgroup rollout
fi

# Add the user to the rollout group, if not already there
if ! groups ${username} | grep "\brollout\b" > /dev/null 2>&1
then
	usermod -a -G rollout ${username}
fi

# Add the person installing the software to the rollout group, for convenience, if not already there
if ! groups ${currentActualUser} | grep "\brollout\b" > /dev/null 2>&1
then
	usermod -a -G rollout ${currentActualUser}
fi

# Working directory
mkdir -p /websites

# Own the folder and set the group to be rollout:
chown ${username}:rollout /websites

# Allow sharing of private groups (i.e. new files are created group writeable)
# !! This won't work for any sections run using ${asCS} because in those cases the umask will be inherited from the cyclestreets user's login profile.
umask 0002

# This is the clever bit which adds the setgid bit, it relies on the value of umask.
# It means that all files and folders that are descendants of this folder recursively inherit its group, ie. rollout.
# (The equivalent for the setuid bit does not work because of security issues and so file owners are set later on in the script.)
chmod g+ws /websites

# The following folders and files are be created with root as owner, but that is fixed later on in the script.

# Add the path to content (the -p option creates the intermediate www)
mkdir -p ${websitesContentFolder}

# Create a folder for Apache to log access / errors:
mkdir -p ${websitesLogsFolder}

# Create a folder for backups
mkdir -p ${websitesBackupsFolder}

# Setup a file to record unidentified itineraries
touch ${websitesBackupsFolder}/map_unidentifiedItinerary_archive.csv
chown www-data ${websitesBackupsFolder}/map_unidentifiedItinerary_archive.csv


# Switch to content folder
cd ${websitesContentFolder}

# Create/update the CycleStreets repository, ensuring that the files are owned by the CycleStreets user (but the checkout should use the current user's account - see http://stackoverflow.com/a/4597929/180733 )
if [ ! -d ${websitesContentFolder}/.svn ]
then
    ${asCS} svn co --username=${currentActualUser} --no-auth-cache http://svn.cyclestreets.net/cyclestreets ${websitesContentFolder} >> ${setupLogFile}
else
    ${asCS} svn update --username=${currentActualUser} --no-auth-cache >> ${setupLogFile}
fi

# Assume ownership of all the new files and folders
chown -R ${username} /websites

# Add group writability.
# This is necessary because although the umask is set correctly above (for the root user) the folder structure has been created via the svn co/update under ${asCS}
chmod -R g+w /websites

# Allow the Apache webserver process to write / add to the data/ folder
chown -R www-data ${websitesContentFolder}/data

# Geolocation by synchronization
# https://github.com/cyclestreets/cyclestreets/wiki/GPS-Syncronization
# For gpsPhoto.pl, add dependencies
apt-get -y install libimage-exiftool-perl
# This one might not actually be needed
apt-get -y install libxml-dom-perl
# Ensure the webserver (and group, but not others ideally) have executability on gpsPhoto.pl
chown www-data ${websitesContentFolder}/libraries/gpsPhoto.pl
chmod -x ${websitesContentFolder}/libraries/gpsPhoto.pl
chmod ug+x ${websitesContentFolder}/libraries/gpsPhoto.pl

# Select changelog
touch ${websitesContentFolder}/documentation/schema/selectChangeLog.sql
chown www-data:rollout ${websitesContentFolder}/documentation/schema/selectChangeLog.sql

# Requested missing cities logging (will disappear when ticket 645 cleared up)
touch ${websitesContentFolder}/documentation/RequestedMissingCities.tsv
chown www-data:rollout ${websitesContentFolder}/documentation/RequestedMissingCities.tsv

# Mod rewrite
a2enmod rewrite >> ${setupLogFile}

# Virtual host configuration - for best compatibiliy use *.conf for the apache configuration files
cslocalconf=cslocalhost.conf
localVirtualHostFile=/etc/apache2/sites-available/${cslocalconf}

# Check if the local virtual host exists already
if [ ! -r ${localVirtualHostFile} ]; then
    # Create the local virtual host (avoid any backquotes in the text as they'll spawn sub-processes)
    cat > ${localVirtualHostFile} << EOF
<VirtualHost *:80>

	# Available URL(s)
	# Note: ServerName should not use wildcards, use ServerAlias for that.
	ServerName localhost
	ServerAlias *.localhost

	# Logging
	CustomLog /websites/www/logs/access.log combined
	ErrorLog /websites/www/logs/error.log

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
    chown ${username}:rollout ${localVirtualHostFile}

else
    echo "#	Virtual host already exists: ${localVirtualHostFile}"
fi

# Enable this virtual host
a2ensite ${cslocalconf}

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
    echo "#	Could not decide where to put global virtual host configuration"
    exit 1
fi

echo "#	Setting global virtual host configuration in ${globalApacheConfigFile}"

# Check if the local global apache config file exists already
if [ ! -r ${globalApacheConfigFile} ]; then
    # Create the global apache config file
    cat > ${globalApacheConfigFile} << EOF
# Provides local configuration that affects all hosted sites.

# This file is loaded from the /etc/apache2/conf.d folder, it's name begins with a z so that it is loaded last from that folder.
# The files in the conf.d folder are all loaded before any VirtualHost files.

# Avoid giving away unnecessary information about the webserver configuration
ServerSignature Off
ServerTokens ProductOnly
php_admin_value expose_php 0

# ServerAdmin
ServerAdmin ${administratorEmail}

# PHP environment
php_value short_open_tag off

# Unicode UTF-8
AddDefaultCharset utf-8

# Disallow /somepage.php/Foo to load somepage.php
AcceptPathInfo Off

# Logging
LogLevel warn

# Statistics
Alias /images/statsicons /websites/configuration/analog/images

# Ensure FCKeditor .xml files have the correct MIME type
<Location /_fckeditor/>
	AddType application/xml .xml
</Location>

# Deny photomap file reading directly
<Directory /websites/www/content/data/photomap/>
	deny from all
</Directory>
<Directory /websites/www/content/data/photomap2/>
	deny from all
</Directory>

# Disallow loading of .svn folder contents
<DirectoryMatch .*\.svn/.*>
	Deny From All
</DirectoryMatch>

# Deny access to areas not intended to be public
<LocationMatch ^/(archive|configuration|documentation|import|classes|libraries|scripts|routingengine)>
	order deny,allow
	deny from all
</LocationMatch>

# Disallow use of .htaccess file directives by default
<Directory />
	# Options FollowSymLinks
	AllowOverride None
	# In Apache 2.4 uncomment this next line
	# Require all granted
</Directory>

# Allow use of RewriteRules (which one of the things allowed by the "FileInfo" type of override) for the blog area
<Directory /websites/www/content/blog/>
	AllowOverride FileInfo
</Directory>

EOF

    # Add IP bans - quoted to preserve newlines
    echo "${ipbans}" >> ${globalApacheConfigFile}
else
    echo "#	Global apache configuration file already exists: ${globalApacheConfigFile}"
fi

# Enable the configuration file (only necessary in Apache 2.4)
if [ -d /etc/apache2/conf-available ]; then
    a2enconf ${zcsGlobalConf}
fi

# Reload apache
service apache2 reload >> ${setupLogFile}

# Database setup
# Useful binding
mysql="mysql -uroot -p${mysqlRootPassword} -hlocalhost"

# Create cyclestreets database
${mysql} -e "create database if not exists cyclestreets default character set utf8 collate utf8_unicode_ci;" >> ${setupLogFile}

# Users are created by the grant command if they do not exist, making these idem potent.
# The grant is relative to localhost as it will be the apache server that authenticates against the local mysql.
${mysql} -e "grant select, insert, update, delete, execute on cyclestreets.* to '${mysqlWebsiteUsername}'@'localhost' identified by '${mysqlWebsitePassword}';" >> ${setupLogFile}
${mysql} -e "grant select, execute on \`routing%\` . * to '${mysqlWebsiteUsername}'@'localhost';" >> ${setupLogFile}

# Update-able blogs
if [ -n "${blogDatabasename}" ]; then
    # http://stackoverflow.com/questions/91805/what-database-privileges-does-a-wordpress-blog-really-need
    blogPermissions="select, insert, update, delete, alter, create, index, drop, create temporary tables"
    ${mysql} -e "grant ${blogPermissions} on ${blogDatabasename}.* to '${blogUsername}'@'localhost' identified by '${blogPassword}';" >> ${setupLogFile}
    ${mysql} -e "grant ${blogPermissions} on ${cyclescapeBlogDatabasename}.* to '${cyclescapeBlogUsername}'@'localhost' identified by '${cyclescapeBlogPassword}';" >> ${setupLogFile}
fi

# The following is needed only to support OSM import
${mysql} -e "grant select on \`planetExtractOSM%\` . * to '${mysqlWebsiteUsername}'@'localhost';" >> ${setupLogFile}

# Create the settings file if it doesn't exist
phpConfig=".config.php"
if [ ! -e ${websitesContentFolder}/${phpConfig} ]
then
    cp -p .config.php.template ${phpConfig}
fi

# Setup the config?
if grep WEBSITE_USERNAME_HERE ${phpConfig} >/dev/null 2>&1;
then

    # Make the substitutions
    echo "#	Configuring the ${phpConfig}";
    sed -i \
-e "s/WEBSITE_USERNAME_HERE/${mysqlWebsiteUsername}/" \
-e "s/WEBSITE_PASSWORD_HERE/${mysqlWebsitePassword}/" \
-e "s/ADMIN_EMAIL_HERE/${administratorEmail}/" \
-e "s/YOUR_EMAIL_HERE/${mainEmail}/" \
-e "s/YOUR_SALT_HERE/${signinSalt}/" \
	${phpConfig}
fi


# Data

# Install a basic cyclestreets db from the repository
# Unless the cyclestreets db has already been loaded (check for presence of map_config table)
if ! ${mysql} --batch --skip-column-names -e "SHOW tables LIKE 'map_config'" cyclestreets | grep map_config  > /dev/null 2>&1
then
    # Load cyclestreets data
    echo "#	Load cyclestreets data"
    ${mysql} cyclestreets < ${websitesContentFolder}/documentation/schema/cyclestreetsSample.sql >> ${setupLogFile}

    # Create an admin user
    encryption=`php -r"echo crypt(\"${password}\", \"${signinSalt}\");"`
    ${mysql} cyclestreets -e "insert user_user (username, email, name, privileges, encryption, validated) values ('${username}', '${administratorEmail}', 'Admin Account', 'administrator', '${encryption}', '2013-08-15 09:45:18');" >> ${setupLogFile}

    # Create a welcome tinkle
    ${mysql} cyclestreets -e "insert tinkle (userId, tinkle) values (1, 'Welcome to CycleStreets');" >> ${setupLogFile}
fi

# Archive db
archiveDb=csArchive
# Unless the database already exists:
if ! ${mysql} --batch --skip-column-names -e "SHOW DATABASES LIKE '${archiveDb}'" | grep ${archiveDb} > /dev/null 2>&1
then
    # Create basicRoutingDb database
    echo "#	Create ${archiveDb} database"
    ${mysql} < ${websitesContentFolder}/documentation/schema/csArchive.sql >> ${setupLogFile}

    # Allow website read only access
    ${mysql} -e "grant select on \`${archiveDb}\` . * to '${mysqlWebsiteUsername}'@'localhost';" >> ${setupLogFile}
fi

# External db
# This creates only a skeleton and sets up grant permissions. The full installation is done by a script in install-import folder.
# Unless the database already exists:
if ! ${mysql} --batch --skip-column-names -e "SHOW DATABASES LIKE '${externalDb}'" | grep ${externalDb} > /dev/null 2>&1
then
    # Create basicRoutingDb database
    echo "#	Create ${externalDb} database"
    # !! Need to provide a place from where a full version can be downloaded.
    echo "#	Note: this contains table definitions only and contains no data. A full version must be downloaded separately."
    ${mysql} < ${websitesContentFolder}/documentation/schema/csExternal.sql >> ${setupLogFile}

    # Allow website read only access
    ${mysql} -e "grant select on \`${externalDb}\` . * to '${mysqlWebsiteUsername}'@'localhost';" >> ${setupLogFile}
fi

# Install a basic routing db from the repository
basicRoutingDb=routing130815
# Unless the database already exists:
if ! ${mysql} --batch --skip-column-names -e "SHOW DATABASES LIKE '${basicRoutingDb}'" | grep ${basicRoutingDb} > /dev/null 2>&1
then
    # Create basicRoutingDb database
    echo "#	Create ${basicRoutingDb} database"
    ${mysql} -e "create database if not exists ${basicRoutingDb} default character set utf8 collate utf8_unicode_ci;" >> ${setupLogFile}

    # Load data
    echo "#	Load ${basicRoutingDb} data"
    gunzip < ${websitesContentFolder}/documentation/schema/routingSample.sql.gz | ${mysql} ${basicRoutingDb} >> ${setupLogFile}
fi

# Create a config if not already present
routingEngineConfigFile=${websitesContentFolder}/routingengine/.config.sh
if [ ! -x "${routingEngineConfigFile}" ]; then
	# Create the config for the basic routing db, as cyclestreets user
	${asCS} touch "${routingEngineConfigFile}"
	${asCS} echo -e "#!/bin/bash\nBASEDIR=${websitesContentFolder}/data/routing/${basicRoutingDb}" > "${routingEngineConfigFile}"
	# Ensure it is executable
	chmod a+x "${routingEngineConfigFile}"
fi

# Compile the C++ module; see: https://github.com/cyclestreets/cyclestreets/wiki/Python-routing---starting-and-monitoring
sudo apt-get -y install gcc g++ python-dev >> ${setupLogFile}
if [ ! -e ${websitesContentFolder}/routingengine/astar_impl.so ]; then
	echo "Now building the C++ routing module..."
	cd "${websitesContentFolder}/routingengine/"
	${asCS} python setup.py build
	${asCS} mv build/lib.*/astar_impl.so ./
	${asCS} rm -rf build/
	cd ${websitesContentFolder}
fi

# Add this python module which is needed by the routing_server.py script
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
    if [ ! -L /etc/init.d/cycleroutingd ]; then
	ln -s ${websitesContentFolder}/routingengine/cyclerouting.init.d /etc/init.d/cycleroutingd
    fi

    # Ensure the relevant files are executable
    chmod ug+x ${websitesContentFolder}/routingengine/cyclerouting.init.d
    chmod ug+x ${websitesContentFolder}/routingengine/routing_server.py

    # Start the service
    # Acutally uses the restart option, which is more idempotent
    service cycleroutingd restart
    echo -e "\n# Follow the routing log using: tail -f ${websitesLogsFolder}/pythonAstarPort9000.log"

    # Add the daemon to the system initialization, so that it will start on reboot
    update-rc.d cycleroutingd defaults

else

    echo "#	Routing service - (not installed as a daemon)"
    echo "#	Can be manually started from the command line using:"
    echo "#	sudo -u cyclestreets ${websitesContentFolder}/routingengine/routing_server.py"

    # If it was previously setup as a daemon, remove it
    if [ -L /etc/init.d/cycleroutingd ]; then

	# Ensure it is stopped
	service cycleroutingd stop

	# Remove the symlink
	rm /etc/init.d/cycleroutingd

	# Remove the daemon from the system initialization
	update-rc.d cycleroutingd remove
    fi

fi


# Confirm end of script
msg="#	All now installed $(date)"
echo $msg >> ${setupLogFile}
echo $msg

# Return true to indicate success
:

# End of file
