# Installs a base webserver machine with webserver software (Apache, PHP, MySQL), relevant users and main directory


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

    # Can't easily create usernames on the Mac
    if [ $baseOS = "Mac" ]; then
	echo "#	Can't easily create usernames on the Mac"
	exit 1
    fi

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

# Installer
[[ $baseOS = "Ubuntu" ]] && packageInstall="apt-get -y install" || packageInstall="brew install"
[[ $baseOS = "Ubuntu" ]] && packageUpdate="apt-get update" || packageUpdate="brew update"

# Prepare the apt index; it may be practically non-existent on a fresh VM
$packageUpdate > /dev/null

# Bring the machine distribution up to date by updating all existing packages
apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y autoremove

# Install basic software
$packageInstall wget dnsutils man-db subversion git emacs nano bzip2

# Install Apache, PHP
echo "#	Installing Apache, MySQL, PHP"

is_installed () {
	dpkg -s "$1" | grep -q '^Status:.*installed'
}

# Assign the mysql root password - to avoid being prompted.
if [ -z "${mysqlRootPassword}" ] && ! is_installed mysql-server ; then
	echo "# It appears that either no MySQL root password has been specified in the config file or that there is no MySQL server installed."
	echo "# This means the install script would get stuck prompting for one."
	echo "# Abandoning the installation."
	exit 1
fi
echo mysql-server mysql-server/root_password password ${mysqlRootPassword} | debconf-set-selections
echo mysql-server mysql-server/root_password_again password ${mysqlRootPassword} | debconf-set-selections

# Install MySQL 5.6, which will also start it
$packageInstall mysql-server-5.6 mysql-client-5.6

# Install Apache (2.4)
echo "#	Installing core webserver packages"
$packageInstall apache2

# Enable core Apache modules
a2enmod rewrite
a2enmod headers

# The server version of ubuntu 14.04.2 LTS does not include add-apt-repository so this adds it:
$packageInstall python-software-properties software-properties-common

# PHP 5.6; see: http://phpave.com/upgrade-to-php-56-on-ubuntu-1404-lts/
add-apt-repository -y ppa:ondrej/php5-5.6
$packageUpdate
$packageInstall php5 php5-gd php5-cli php5-mysql

# This package prompts for configuration, and so is left out of this script as it is only a developer tool which can be installed later.
# $packageInstall phpmyadmin

# Determine the current actual user
currentActualUser=`who am i | awk '{print $1}'`

# Create the rollout group, if it does not already exist
if ! grep -i "^${rollout}\b" /etc/group > /dev/null 2>&1
then
    addgroup ${rollout}
fi

# Add the user to the rollout group, if not already there
if ! groups ${username} | grep "\b${rollout}\b" > /dev/null 2>&1
then
	usermod -a -G ${rollout} ${username}
fi

# Add the person installing the software to the rollout group, for convenience, if not already there
if ! groups ${currentActualUser} | grep "\b${rollout}\b" > /dev/null 2>&1
then
	usermod -a -G ${rollout} ${currentActualUser}
fi

# Working directory
mkdir -p /websites

# Own the folder and set the group to be rollout:
chown ${username}:${rollout} /websites

# Allow sharing of private groups (i.e. new files are created group writeable)
# !! This won't work for any sections run using ${asCS} because in those cases the umask will be inherited from the cyclestreets user's login profile.
umask 0002

# This is the clever bit which adds the setgid bit, it relies on the value of umask.
# It means that all files and folders that are descendants of this folder recursively inherit its group, ie. rollout.
# (The equivalent for the setuid bit does not work because of security issues and so file owners are set later on in the script.)
chmod g+ws /websites
# The following folders and files are be created with root as owner, but that is fixed later on in the script.

# Create a folder for Apache to log access / errors:
mkdir -p ${websitesLogsFolder}

# Create a folder for backups
mkdir -p ${websitesBackupsFolder}

# Setup a .cnf file which sets up mysql to connect with utf8mb4 for greatest compatibility
mysqlUtf8CnfFile=/etc/mysql/conf.d/utf8.cnf
if [ ! -e ${mysqlUtf8CnfFile} ]; then

    # Narrative
    echo "#	Configure mysql for utf8mb4"

    # Create the file
    touch ${mysqlUtf8CnfFile}

    # Own by the user
    chown ${username}:${rollout} ${mysqlUtf8CnfFile}

    # Write config
    # https://mathiasbynens.be/notes/mysql-utf8mb4
    cat > ${mysqlUtf8CnfFile} << EOF
[client]
default-character-set=utf8mb4

[mysql]
default-character-set=utf8mb4

[mysqld]
character-set-client-handshake = FALSE
collation-server = utf8mb4_unicode_ci
character-set-server = utf8mb4
sql_mode=NO_ENGINE_SUBSTITUTION
EOF

    # Restart mysql
    service mysql restart

fi


# Setup a ~/.my.cnf file which will allow the CycleStreets user to run mysql commands (as the superuser) without supplying command line password
# !! Be wary of this as the settings in here will override those in any supplied defaults-extra-file
if [ ! -e ${mySuperCredFile} ]; then

    # Create the file owned by the user
    ${asCS} touch ${mySuperCredFile}

    # Remove other readability
    ${asCS} chmod o-r ${mySuperCredFile}

    # Write config
    ${asCS} cat > ${mySuperCredFile} << EOF
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

# Disable AppArmor for MySQL if present, which interferes with LOAD DATA INFILE; see: https://blogs.oracle.com/jsmyth/entry/apparmor_and_mysql and http://www.cyberciti.biz/faq/ubuntu-linux-howto-disable-apparmor-commands/
if [ -f /etc/apparmor.d/usr.sbin.mysqld ]; then
	ln -s /etc/apparmor.d/usr.sbin.mysqld /etc/apparmor.d/disable/
	apparmor_parser -R /etc/apparmor.d/usr.sbin.mysqld
fi


# End of file
