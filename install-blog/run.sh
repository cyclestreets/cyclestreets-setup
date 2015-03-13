#!/bin/bash
# Script to install the CycleStreets blog on Ubuntu
# Tested on 14.04 LTS Server (View Ubuntu version using 'lsb_release -a')
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
# The second single line solution from that page is probably good enough as it is unlikely that this script itself will be symlinked.
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SCRIPTDIRECTORY=$DIR

# Name of the credentials file
configFile=../.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x ./${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file."
    exit 1
fi

# Load the credentials
. ./${configFile}

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

# Database setup Useful binding
mysql="mysql -uroot -p${mysqlRootPassword} -hlocalhost"

# http://stackoverflow.com/questions/91805/what-database-privileges-does-a-wordpress-blog-really-need
blogPermissions="select, insert, update, delete, alter, create, index, drop, create temporary tables"
${mysql} -e "grant ${blogPermissions} on ${blogDatabasename}.* to '${blogUsername}'@'localhost' identified by '${blogPassword}';" >> ${setupLogFile}
#${mysql} -e "grant ${blogPermissions} on ${cyclescapeBlogDatabasename}.* to '${cyclescapeBlogUsername}'@'localhost' identified by '${cyclescapeBlogPassword}';" >> ${setupLogFile}


#!# Install Wordpress unattended


# Define an Apache configuration file that will be used for blog directives
if [ -d /etc/apache2/conf-available ]; then
    # Apache 2.4 location
    blogsConfigFile=/etc/apache2/conf-available/blogs.conf
elif [ -d /etc/apache2/conf.d ]; then
    # Apache 2.2 location
    blogsConfigFile=/etc/apache2/conf.d/blogs.conf
else
    echo "#	Could not decide where to put global virtual host configuration"
    exit 1
fi

# If the Apache blog directives file doesn't exist, create it, adding the directives
if [ ! -f ${blogsConfigFile} ]; then
    cat > ${blogsConfigFile} << EOF


## This file contains directives applying to all blogs on the server

# Allow use of RewriteRules (which one of the things allowed by the FileInfo type of override)
<Directory /websites/www/content/blog/>
	AllowOverride FileInfo
</Directory>

# Use an authentication dialog for login to the blog as this page is subject to attack
<FilesMatch wp-login.php>
	AuthName "WordPress Admin"
	AuthType Basic
	AuthUserFile /websites/configuration/apache/.htpasswd
	Require valid-user
</FilesMatch>


EOF
fi

# Enable the new configuration (Apache 2.4 only)
if [ -d /etc/apache2/conf-available ]; then
	a2enconf blogs
fi

# Reload apache
/etc/init.d/apache2 reload >> ${setupLogFile}

# Confirm end of script
msg="#	All now installed $(date)"
echo $msg >> ${setupLogFile}
echo $msg

# Return true to indicate success
:

# End of file
