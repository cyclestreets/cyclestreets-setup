#!/bin/bash
# Script to install CycleStreets on Ubuntu
# Tested on 12.04 (View Ubuntu version using 'lsb_release -a') using Postgres 9.1
# http://wiki.openstreetmap.org/wiki/Nominatim/Installation#Ubuntu.2FDebian

echo "#	CycleStreets installation $(date)"

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#	This script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

### CREDENTIALS ###
# Name of the credentials file
configFile=.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -e ./${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. ./${configFile}

# Logging
# Use an absolute path for the log file to be tolerant of the changing working directory in this script
setupLogFile=$(readlink -e $(dirname $0))/setupLog.txt
touch ${setupLogFile}
echo "#	CycleStreets installation in progress, follow log file with: tail -f ${setupLogFile}"
echo "#	CycleStreets installation $(date)" >> ${setupLogFile}

# Ensure there is a cyclestreets user account
if id -u ${username} >/dev/null 2>&1; then
    echo "#	User ${username} exists already and will be used."
else
    echo "#\User ${username} does not exist: creating now."

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
    # !! The password supplied here should be an enrcypted version.
    # The work-around is to set the password using passwd as super user afterwards.
    useradd -m -p "EncryptedPassword" $username
    echo "#	CycleStreets user ${username} created" >> ${setupLogFile}
fi

# Check whether the user is alredy in the sudo group
if ! groups ${username} | grep "\bsudo\b" > /dev/null 2>&1
then
    # Add the user to it
    adduser ${username} sudo
fi


# Shortcut for running commands as the cyclestreets users
asCS="sudo -u ${username}"

# Install basic software
apt-get -y install wget git emacs >> ${setupLogFile}

# Install Apache, PHP
echo "#	Installing Apache, MySQL, PHP" >> ${setupLogFile}

# Provide the mysql root password - to avoid being prompted.
echo mysql-server mysql-server/root_password password ${mysqlRootPassword} | debconf-set-selections
echo mysql-server mysql-server/root_password_again password ${mysqlRootPassword} | debconf-set-selections

apt-get -y install apache2 mysql-server mysql-client php5 php5-gd php5-cli php5-mysql >> ${setupLogFile}

# Install Python
echo "#	Installing python" >> ${setupLogFile}
apt-get -y install python php5-xmlrpc php5-curl >> ${setupLogFile}

# Utilities
echo "#	Some utilities" >> ${setupLogFile}
apt-get -y install subversion openjdk-6-jre bzip2 ffmpeg >> ${setupLogFile}

# This package prompts for configuration, and so is left out of this script as it is only a developer tool which can be installed later.
# apt-get -y install phpmyadmin

#   ___
# /     \
# |  1  | 
# |     |
# -------
# Milestone 1
echo "# Reached milestone 1"

# Check if the rollout group exists
if ! grep -i "^rollout\b" /etc/group > /dev/null 2>&1
then

    # Create the roll out group
    addgroup rollout

fi

# Check whether the user is alredy in the rollout group
if ! groups ${username} | grep "\brollout\b" > /dev/null 2>&1
then
    # Add the user to it
    adduser ${username} rollout
fi

# Working directory
mkdir -p /websites

# Set the group for the containing folder to be rollout:
chown ${username}:rollout /websites

# Allow sharing of private groups
umask 0002

# This is the clever bit which adds the setgid bit, it relies on the value of umask.
# It means that all files and folders that are descendants of this folder recursively inherit it's group, ie. rollout.
chmod g+ws /websites

# Add the path to content (the -p option creates the intermediate www)
mkdir -p ${websitesContentFolder}

# Create a folder for Apache to log access / errors:
mkdir -p ${websitesLogsFolder}

# Create a folder for schema backups
mkdir -p ${websitesBackupsFolder}

# Switch to content folder
cd ${websitesContentFolder}

# Check if the repository has been created
if [ ! -d ${websitesContentFolder}/.svn ]
then
    # Populate with source code by checking out from the CycleStreets repository:
    ${asCS} svn co http://svn.cyclestreets.net/cyclestreets ${websitesContentFolder} >> ${setupLogFile}
fi

# Mod rewrite
a2enmod rewrite >> ${setupLogFile}

# Virtual host configuration
# Create symbolic link if it doesn't already exist
if [ ! -L /etc/apache2/sites-available/cslocalhost ]; then
    ln -s ${websitesContentFolder}/configuration/apache/sites-available/cslocalhost /etc/apache2/sites-available/
fi
a2ensite cslocalhost >> ${setupLogFile}

# Reload apache
service apache2 reload >> ${setupLogFile}

#   ___
# /     \
# |  2  | 
# |     |
# -------
# Milestone 2
echo "# Reached milestone 2"

# Database setup
# Shortcut
mysql="mysql -uroot -p${mysqlRootPassword} -hlocalhost"

# Create cyclestreets database
${mysql} -e "create database if not exists cyclestreets default character set utf8 collate utf8_unicode_ci;" >> ${setupLogFile}

# Users are created by the grant command if they do not exist, making these idem potent.
# The grant is relative to localhost as it will be the apache server that authenticates against the local mysql.
${mysql} -e "grant select, insert, update, delete, execute on cyclestreets.* to '${mysqlWebsiteUsername}'@'localhost' identified by '${mysqlWebsitePassword}';" >> ${setupLogFile}
${mysql} -e "grant select, execute on \`routing%\` . * to '${mysqlWebsiteUsername}'@'localhost' identified by '${mysqlWebsitePassword}';" >> ${setupLogFile}

# Update-able blogs
${mysql} -e "grant select, insert, update, delete, execute on \`blog%\` . * to '${mysqlWebsiteUsername}'@'localhost' identified by '${mysqlWebsitePassword}';" >> ${setupLogFile}

# The following is needed only to support OSM import
${mysql} -e "grant select on \`planetExtractOSM%\` . * to '${mysqlWebsiteUsername}'@'localhost';" >> ${setupLogFile}


# Data

# !! Had to add this step to make sure the folder is owned by cyclestreets - there must be a tidier way of dealing with these permissions
chown ${username} ${websitesBackupsFolder}

# !! SKIPPED - use something like this:
# scp backupserver...:/websites/www/backups/www_cyclestreets.sql.gz ${websitesBackupsFolder}
# gunzip < .sql.gz | mysql cyclestreets -uroot -p...

# Configure the settings file
phpConfig=".config.php"
if [ ! -e ${websitesContentFolder}/${phpConfig} ]
then
    # !! Note: when the .config.php already exists any new settings will be skipped
    echo "#	Configuring a new ${phpConfig}";
    sed \
-e "s/[#]*\$config\['username'] = 'WEBSITE_USERNAME_HERE';/\$config\['username'] = '${mysqlWebsiteUsername}';/" \
-e "s/[#]*\$config\['password'] = 'WEBSITE_PASSWORD_HERE';/\$config\['password'] = '${mysqlWebsitePassword}';/" \
-e "s/[#]*\$config\['administratorEmail'] = 'YOUR_EMAIL_HERE';/\$config\['administratorEmail'] = '${administratorEmail}';/" \
-e "s/[#]*\$config\['mainEmail'] = 'YOUR_EMAIL_HERE';/\$config\['mainEmail'] = '${mainEmail}';/" \
	.config.php.template > ${phpConfig}

    # Make it executable
    chmod a+x ${phpConfig}
else
    echo "#	!! Re-using ${phpConfig} - which will miss any new settings";
fi

# Narrate the end of script
echo "# Reached end of installation script"
