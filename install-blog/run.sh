#!/bin/bash
# Script to install the CycleStreets blog on Ubuntu
# Written for Ubuntu Server 22.04 LTS (View Ubuntu version using 'lsb_release -a')
# This script is idempotent - it can be safely re-run without destroying existing data

echo "#	CycleStreets blog installation $(date)"

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#	This script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e


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

# Name of the credentials file
configFile=../.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x $SCRIPTDIRECTORY/${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist or is not executable - copy your own based on the ${configFile}.template file."
    exit 1
fi

# Load the credentials
. $SCRIPTDIRECTORY/${configFile}

# Logging
# Use an absolute path for the log file to be tolerant of the changing working directory in this script
setupLogFile=$SCRIPTDIRECTORY/log.txt
touch ${setupLogFile}
echo "#	CycleStreets blog installation in progress, follow log file with: tail -f ${setupLogFile}"
echo "#	CycleStreets blog installation $(date)" >> ${setupLogFile}


# Ensure that the blog database is defined
if [ -z "${blogDatabasename}" ]; then
	echo "# No blog database name has been defined, so there is nothing to do."
	exit 1
fi;

# Ensure that the blog moniker is defined
if [ -z "${blogMoniker}" ]; then
	echo "# No blog moniker has been defined, so there is nothing to do."
	exit 1
fi;

# Useful binding
# The defaults-extra-file is a positional argument which must come first.
superMysql="mysql -u root --password=${mysqlRootPassword}"

# Create database
${superMysql} -e "CREATE DATABASE IF NOT EXISTS ${blogDatabasename};"

# Create database permissions
# http://stackoverflow.com/questions/91805/what-database-privileges-does-a-wordpress-blog-really-need
blogPermissions="select, insert, update, delete, alter, create, index, drop, create temporary tables"
${superMysql} -e "CREATE USER IF NOT EXISTS '${blogUsername}'@'localhost' IDENTIFIED BY '${blogPassword}';" >> ${setupLogFile}
${superMysql} -e "grant ${blogPermissions} on ${blogDatabasename}.* to '${blogUsername}'@'localhost';" >> ${setupLogFile}
${superMysql} -e "flush privileges;"

# Wordpress CLI; see: https://wp-cli.org/
if [ ! -f /usr/local/bin/wp ]; then
	wget -O /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
	chmod +x /usr/local/bin/wp
fi

# Install Wordpress unattended
#!# Replace with wp cli method
if [ ! -f /websites/${blogMoniker}/content/index.php ]; then
	mkdir -p /websites/${blogMoniker}/content/
	wget -P /tmp/ https://wordpress.org/latest.tar.gz
	tar -xzvf /tmp/latest.tar.gz --strip 1 -C /websites/${blogMoniker}/content/
	rm /tmp/latest.tar.gz
	echo "Unpacked Wordpress files"
fi

# Ensure the blog files are writable, as otherwise automatic upgrade will fail
chown -R www-data.rollout /websites/${blogMoniker}/content/

# Create the VirtualHost
vhConf=/etc/apache2/sites-available/${blogMoniker}.conf
if [ ! -f ${vhConf} ]; then
    cat > ${vhConf} << EOF

<VirtualHost *:80>
	
	# Available URL(s)
	ServerName ${blogMoniker}.example.com
	
	# Where the files are
	DocumentRoot /websites/${blogMoniker}/content/
	
	# Logging
	CustomLog /websites/www/logs/${blogMoniker}-access.log combined
	ErrorLog /websites/www/logs/${blogMoniker}-error.log
	
	# Allow access
	<Location />
		Require all granted
	</Location>
	
	# Allow use of RewriteRules (which one of the things allowed by the FileInfo type of override), and Require (e.g. for Akismet's .htaccess)
	<Directory /websites/${blogMoniker}/content/>
		AllowOverride FileInfo Options Limit AuthConfig
	</Directory>
	
	# Use an authentication dialog for login to the blog as this page is subject to attack
	<FilesMatch wp-login.php>
		AuthName "WordPress Admin"
		AuthType Basic
		AuthUserFile /websites/configuration/apache/.htpasswd
		Require valid-user
	</FilesMatch>
	
</VirtualHost>

EOF
fi

# Enable the new configuration
a2ensite ${blogMoniker}

# Reload apache
service apache2 reload >> ${setupLogFile}

# Confirm end of script
msg="#	All now installed $(date)"
echo $msg >> ${setupLogFile}
echo $msg

# Return true to indicate success
:

# End of file
