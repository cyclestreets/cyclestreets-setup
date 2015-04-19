# Sections of script that are common to install-website and install-import

# Tolerate errors for the readlink
set +e

# Identify the source of the configuration, depending on whether the config is a symlink
if [ -L ${configFile} ]; then
    # Read the target
    sourceConfig=$(readlink -q ${configFile})
    sourceConfig=" via symlink: ${sourceConfig}"
else
    # Use this simple text
    sourceConfig=" by local configuration."
fi

# Bomb out if something goes wrong
set -e

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

# Ensure there's a custom sudoers file
if [ -n "${csSudoers}" -a ! -e "${csSudoers}" ]; then

    # Create it file that provides passwordless sudo access to the routing service - which needs root access to control running service
    cat > ${csSudoers} << EOF
# Permit cyclestreets user to control the routing service without a password
cyclestreets ALL = (root) NOPASSWD: ${routingDaemonLocation}
EOF

    # Extra option for import
    if [ -n "${importContentFolder}" ]; then

	# Add passwordless sudo access to routing compression (which needs access to raw mysql files)
	cat >> ${csSudoers} << EOF
# Permit cyclestreets user to run the routing compression using sudo without a password
cyclestreets ALL = (root) NOPASSWD: ${importContentFolder}/compressRouting.sh
EOF
    fi

    # Make it read only
    chmod 440 ${csSudoers}
fi

# Prepare the apt index; it may be practically non-existent on a fresh VM
apt-get update > /dev/null

# Install basic software
apt-get -y install wget subversion git emacs bzip2

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

## !! Not sure why this was ever necessary
# echo PURGE | debconf-communicate  mysql-server-5.6

# Install Apache (2.4)
echo "#	Installing core webserver packages"
apt-get -y install apache2

# The server version of ubuntu 14.04.2 LTS does not include add-apt-repository so this adds it:
apt-get -y install python-software-properties software-properties-common

# PHP 5.6; see: http://phpave.com/upgrade-to-php-56-on-ubuntu-1404-lts/
add-apt-repository -y ppa:ondrej/php5-5.6
apt-get update
apt-get -y install php5 php5-gd php5-cli php5-mysql

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


# Switch to content folder
cd ${websitesContentFolder}

# Create/update the CycleStreets repository, ensuring that the files are owned by the CycleStreets user (but the checkout should use the current user's account - see http://stackoverflow.com/a/4597929/180733 )
if [ ! -d ${websitesContentFolder}/.svn ]
then
    ${asCS} svn co --username=${currentActualUser} --password="${repopassword}" --no-auth-cache http://svn.cyclestreets.net/cyclestreets ${websitesContentFolder}
else
    ${asCS} svn update --username=${currentActualUser} --password="${repopassword}" --no-auth-cache
fi

# Assume ownership of all the new files and folders
chown -R ${username} /websites

# Add group writability.
# This is necessary because although the umask is set correctly above (for the root user) the folder structure has been created via the svn co/update under ${asCS}
chmod -R g+w /websites

# Allow the Apache webserver process to write / add to the data/ folder
chown -R www-data ${websitesContentFolder}/data

# Setup a ~/.my.cnf file which will allow the user to run mysql commands without supplying command line password
mycnfFile=/home/${username}/.my.cnf
if [ ! -e ${mycnfFile} ]; then

    # Create config file
    ${asCS} cat > ${mycnfFile} << EOF
[client]
user=root
password=${mysqlRootPassword}
# Best to avoid setting a database as this can confuse scripts, ie leave commented out:
#database=cyclestreets

[mysql]
# Equiv to -A at startup, stops tabs trying to autocomplete
no-auto-rehash
EOF

fi

# Useful binding
# By providing the defaults like this, the use of ${asCS} can be avoided - which can be complicated as it produces double expansion of the arguments - which is messy if passwords contain the dollar symbol.
# The defaults-extra-file is a positional argument which must come first.
mysql="mysql --defaults-extra-file=${mycnfFile} -hlocalhost"
