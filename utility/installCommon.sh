# Sections of script that are common to install-website and install-import


# Add the path to content (the -p option creates the intermediate www)
mkdir -p ${websitesContentFolder}

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
echo "#	Starting a series of recursive chown/chmod to set correct file ownership and permissions"
echo "#	chown -R ${username} ${websitesContentFolder}"
chown -R ${username} ${websitesContentFolder}

# Add group writability
# This is necessary because although the umask is set correctly above (for the root user) the folder structure has been created via the svn co/update under ${asCS}
echo "#	chmod -R g+w ${websitesContentFolder}"
chmod -R g+w ${websitesContentFolder}

# Allow the Apache webserver process to write / add to the data/ folder
echo "#	chown -R www-data ${websitesContentFolder}/data"
chown -R www-data ${websitesContentFolder}/data


# Ensure there's a custom sudoers file
if [ -n "${csSudoers}" -a ! -e "${csSudoers}" -a -n "${routingDaemonLocation}" ]; then

    # !! Potentially add more checks to the variables used in these sudoers expressions, such as ensuring the variables are full paths to the commands.

    # Create file that provides passwordless sudo access to the routing service - which needs root access to control running service
    # A number of other passwordless options are also included when operating in a variety of roles such as doing imports or running backup / restores.
    cat > ${csSudoers} << EOF
# Permit cyclestreets user to control the routing service without a password
cyclestreets ALL = (root) NOPASSWD: ${routingDaemonLocation}
# Permit cyclestreets user to run the routing compression using sudo without a password
cyclestreets ALL = (root) NOPASSWD: ${importContentFolder}/compressRouting.sh
# Permit cyclestreets user to restart mysql, which is useful for resetting the configuration after an import run
cyclestreets ALL = (root) NOPASSWD: /usr/sbin/service mysql restart
# Passwordless sudo to chown photomap files
cyclestreets ALL = (root) NOPASSWD: /opt/cyclestreets-setup/utility/chownPhotomapWwwdata.sh
EOF

    # Make it read only
    chmod 440 ${csSudoers}
fi




# End of file
