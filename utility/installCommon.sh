# Sections of script that are common to install-website and install-import

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
	if [ -z "$password" ]; then
	    echo "#	The password was empty"
	    exit 1
	fi
	printf "\n"
	printf "Confirm that password:"
	read passwordconfirm
	if [ -z "$passwordconfirm" ]; then
	    echo "#	The password was empty"
	    exit 1
	fi
	printf "\n"
	stty echo
	if [ "$password" != "$passwordconfirm" ]; then
	    echo "#	The passwords did not match"
	    exit 1
	fi
    fi

    # Create the CycleStreets user
    useradd -m $username

    # Assign the password - this technique hides it from process listings
    echo "${username}:${password}" | /usr/sbin/chpasswd
    echo "#	CycleStreets user ${username} created"
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
apt-get -y install wget git emacs

# Install Apache, PHP
echo "#	Installing Apache, MySQL, PHP"

is_installed () {
	dpkg -s "$1" | grep -q '^Status:.*installed'
}

# Assign the mysql root password - to avoid being prompted.
if [ -z "${mysqlRootPassword}" ] && ! is_installed mysql-server ; then
	echo "# You have apparently not specified a MySQL root password in the config file"
	echo "# This means the install script would get stuck prompting for one"
	echo "# .. aborting"
	exit 1
fi
echo mysql-server mysql-server/root_password password ${mysqlRootPassword} | debconf-set-selections
echo mysql-server mysql-server/root_password_again password ${mysqlRootPassword} | debconf-set-selections

# Install MySQL 5.6, which will also start it
apt-get -y install mysql-server-5.6 mysql-client-5.6
echo PURGE | debconf-communicate  mysql-server-5.6

# Install Apache (2.4)
echo "#	Installing core webserver packages"
apt-get -y install apache2

# The server version of ubuntu 14.04.2 LTS does not include add-apt-repository so this adds it:
apt-get -y install python-software-properties software-properties-common

# PHP 5.6; see: http://phpave.com/upgrade-to-php-56-on-ubuntu-1404-lts/
add-apt-repository -y ppa:ondrej/php5-5.6
apt-get update
apt-get -y install php5 php5-gd php5-cli php5-mysql

# Install Apache mod_macro for convenience (not an actual requirement for CycleStreets)
apt-get -y install libapache2-mod-macro

# Note: some new versions of php5.5 are missing json functions. This can be easily remedied by including the package: php5-json

# ImageMagick is used to provide enhanced maplet drawing. It is optional - if not present gd is used instead.
apt-get -y install imagemagick php5-imagick

# Apache/PHP performance packages (mod_deflate for Apache, APC cache for PHP)
sudo a2enmod deflate
apt-get -y install php-apc
/etc/init.d/apache2 restart

# Install Python
echo "#	Installing python"
apt-get -y install python php5-xmlrpc php5-curl

# Utilities
echo "#	Some utilities"
# ffmpeg has been removed from this line as not available (needed for translating videos uploaded to photomap)
apt-get -y install subversion openjdk-6-jre bzip2

# Install NTP to keep the clock correct (e.g. to avoid wrong GPS synchronisation timings)
apt-get -y install ntp

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
