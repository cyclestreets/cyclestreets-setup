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

    # Rebind this file because if it contains a tilde ~ that may not have been correctly
    # expanded before the user's home directory was created
    mySuperCredFile=`eval echo ${mySuperCredFile}`

fi

# Add the user to the sudo group, if they are not already present
if ! groups ${username} | grep "\bsudo\b" > /dev/null 2>&1
then
    adduser ${username} sudo
fi

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
# Create a folder for Apache to log access / errors, and backups:
mkdir -p ${websitesLogsFolder}
mkdir -p ${websitesBackupsFolder}


# Shortcut for running commands as the cyclestreets user
asCS="sudo -u ${username}"

# Installer
[[ $baseOS = "Ubuntu" ]] && packageInstall="apt -y install" || packageInstall="brew install"
[[ $baseOS = "Ubuntu" ]] && packageUpdate="apt update" || packageUpdate="brew update"

# Prepare the apt index; it may be practically non-existent on a fresh VM
$packageUpdate > /dev/null

# Bring the machine distribution up to date by updating all existing packages
apt -y upgrade
apt -y dist-upgrade
apt -y autoremove

# Install basic utility software
$packageInstall update-manager-core language-pack-en-base wget dnsutils man-db git nano bzip2 screen dos2unix rsync mlocate
updatedb

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
$packageInstall debconf-i18n
echo mysql-server mysql-server/root_password password ${mysqlRootPassword} | debconf-set-selections
echo mysql-server mysql-server/root_password_again password ${mysqlRootPassword} | debconf-set-selections

# Install MySQL which will also start it
$packageInstall mysql-server mysql-client

# Allow administrative access to this new server from central PhpMyAdmin installation
if [ -n "${phpmyadminMachine}" -a -n "{$mysqlRootPassword}" ] ; then
    # Note: it is also necessary to comment out the line: bind-address = 127.0.0.1
    # on the target machine at /etc/mysql/mysql.conf.d/mysqld.cnf

    mysql -u root -p${mysqlRootPassword} -e "DROP USER IF EXISTS 'root'@'${phpmyadminMachine}';"
    mysql -u root -p${mysqlRootPassword} -e "CREATE USER 'root'@'${phpmyadminMachine}' IDENTIFIED BY '${mysqlRootPassword}';"
    mysql -u root -p${mysqlRootPassword} -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'${phpmyadminMachine}' WITH GRANT OPTION;"
    mysql -u root -p${mysqlRootPassword} -e "FLUSH PRIVILEGES;"
fi

# Disable MySQL password expiry system; see: http://stackoverflow.com/a/41552022
mysql -u root -p${mysqlRootPassword} -e "SET GLOBAL default_password_lifetime = 0;"

# Add performance monitoring for MySQL
$packageInstall mytop

# Install Apache (2.4)
echo "#	Installing core webserver packages"
$packageInstall apache2

# Enable core Apache modules
a2enmod rewrite
a2enmod headers
a2enmod ssl
a2enmod unique_id

# Install a catch-all VirtualHost in Apache to thwart firing of unauthorised CNAMEs at the machine
if [ ! -f /etc/apache2/sites-available/catchall.conf ]; then
	cp -pr ${ScriptHome}/utility/catchall.conf /etc/apache2/sites-available/
	ln -s /etc/apache2/sites-available/catchall.conf /etc/apache2/sites-enabled/000-catchall.conf
	mv /var/www/html/index.html /var/www/html/index.html.original
	cp -pr ${ScriptHome}/utility/catchall.html /var/www/html/index.html
fi

# PHP
$packageInstall php php-xml php-gd php-cli php-mysql libapache2-mod-php php-mbstring

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
prompt=\\u@\\h [\\d]>\\_

[mysqld]
character-set-client-handshake = FALSE
collation-server = utf8mb4_unicode_ci
character-set-server = utf8mb4
sql_mode=NO_ENGINE_SUBSTITUTION
skip-log-bin

# !! The following are not part of utf8 configuration but this a convenient place to put them.

# Use tables rather than files to log problems
log_output=table
slow_query_log = ON
long_query_time = 1

# Set this variable as empty which allows access to any files in any local directory (needed for reading elevations)
secure_file_priv =
EOF

    # Restart mysql
    systemctl restart mysql

fi

# Setup a ~/.my*.cnf file to allow the CycleStreets user to run mysql commands as the superuser without supplying a password.
# !! This is really for developer convenience - and so should move to their personal setup.
if [ -n "${mySuperCredFile}" -a ! -e ${mySuperCredFile} ]; then
		
    # Create the file in the cyclestreets user home folder
    touch ${mySuperCredFile}

    # Remove other readability
    chown ${username}.${username} ${mySuperCredFile}
    chmod o-r ${mySuperCredFile}
		
    # Write config
    # Settings in here will override those in any supplied defaults-extra-file
    cat > ${mySuperCredFile} << EOF
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

# Disable AppArmor for MySQL if present and not already disabled.
# It interferes with LOAD DATA INFILE;
# See: https://blogs.oracle.com/jsmyth/entry/apparmor_and_mysql and http://www.cyberciti.biz/faq/ubuntu-linux-howto-disable-apparmor-commands/
if [ -f /etc/apparmor.d/usr.sbin.mysqld -a ! -f /etc/apparmor.d/disable/usr.sbin.mysqld ]; then
	
	# Narrative
	echo "#	Deactivate apparmor for mysql"
	
	# Symlinking here stops this block from being repeated if the script is re-run
	ln -s /etc/apparmor.d/usr.sbin.mysqld /etc/apparmor.d/disable/
	
	# This may fail, so abandon-on-fail is temporarily turned off
	set +e
	apparmor_parser -R /etc/apparmor.d/usr.sbin.mysqld
	set -e
fi

echo "#	Completed installBaseWebserver"

# End of file
