#!/bin/sh
# Script to install CycleStreets on Ubuntu
# Tested on 12.04 (View Ubuntu version using 'lsb_release -a') using Postgres 9.1
# http://wiki.openstreetmap.org/wiki/Nominatim/Installation#Ubuntu.2FDebian

echo "#\tCycleStreets installation $(date)"

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#\tThis script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

### CREDENTIALS ###
# Name of the credentials file
configFile=.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -e ./${configFile} ]; then
    echo "#\tThe config file, ${configFile}, does not exist - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. ./${configFile}

# Download url
osmdataurl=http://download.geofabrik.de/openstreetmap/${osmdatafolder}${osmdatafilename}

### MAIN PROGRAM ###

# Logging
# Use an absolute path for the log file to be tolerant of the changing working directory in this script
setupLogFile=$(readlink -e $(dirname $0))/setupLog.txt
touch ${setupLogFile}
echo "#\tCycleStreets installation in progress, follow log file with:\n#\ttail -f ${setupLogFile}"
echo "#\tCycleStreets installation $(date)" >> ${setupLogFile}

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
	echo "#\tThe passwords did not match"
	exit 1
    fi
fi

# Create the CycleStreets user
useradd -m -p $password $username
echo "#\tNominatim user ${username} created" >> ${setupLogFile}

# Install basic software
apt-get -y install wget git emacs >> ${setupLogFile}

# Install Apache, PHP
echo "\n#\tInstalling Apache, MySQL, PHP" >> ${setupLogFile}
apt-get -y install apache2 mysql-server mysql-client php5 php5-gd php5-cli php5-mysql >> ${setupLogFile}

# Install Python
echo "\n#\tInstalling python" >> ${setupLogFile}
apt-get -y install python php5-xmlrpc php5-curl >> ${setupLogFile}
echo "\n#\tInstalling utilities" >> ${setupLogFile}
apt-get -y install install phpmyadmin subversion openjdk-6-jre bzip2 ffmpeg >> ${setupLogFile}

# This should get us to milestone 1
