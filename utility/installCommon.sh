# Sections of script that are common to install-website and install-import


# Add the path to content (the -p option creates the intermediate www)
mkdir -p ${websitesContentFolder}

# Switch to content folder
cd ${websitesContentFolder}


# SUDO_USER is the name of the user that invoked the script using sudo
# !! This technique which is a bit like doing an 'unsudo' is messy.
chown ${SUDO_USER} ${websitesContentFolder}

# Create/update the CycleStreets repository from the sudo-invoking user's account
# !! This may prompt for git username / password.
if [ ! -d ${websitesContentFolder}/.git ]
then
	su - ${SUDO_USER} -c "git clone ${repoOrigin}cyclestreets/cyclestreets.git ${websitesContentFolder}"
	git config --global --add safe.directory ${websitesContentFolder}
	
else
    # Set permissions before the update
    chgrp -R rollout ${websitesContentFolder}/.git
    su - ${SUDO_USER} -c "cd ${websitesContentFolder} && git pull"
fi

# Add cronned update of the repo
cp /opt/cyclestreets-setup/live-deployment/cyclestreets-update.cron /etc/cron.d/cyclestreets-update
chown root.root /etc/cron.d/cyclestreets-update
chmod 0600 /etc/cron.d/cyclestreets-update

# Ensure there's a custom sudoers file
csSudoers=/etc/sudoers.d/cyclestreets
if [ -n "${csSudoers}" -a ! -e "${csSudoers}" ]; then

    # !! Potentially add more checks to the variables used in these sudoers expressions, such as ensuring the variables are full paths to the commands.

    # Create file that provides passwordless sudo access to the routing service - which needs root access to control running service
    # A number of other passwordless options are also included when operating in a variety of roles such as doing imports or running backup / restores.
    cat > ${csSudoers} << EOF
# Permit cyclestreets user to control the routing service without a password
cyclestreets ALL = (root) NOPASSWD: /bin/systemctl --no-pager status cyclestreets
cyclestreets ALL = (root) NOPASSWD: /bin/systemctl status cyclestreets
cyclestreets ALL = (root) NOPASSWD: /bin/systemctl start cyclestreets
cyclestreets ALL = (root) NOPASSWD: /bin/systemctl stop cyclestreets
cyclestreets ALL = (root) NOPASSWD: /bin/systemctl restart cyclestreets

# Secondary versions of the above
cyclestreets ALL = (root) NOPASSWD: /bin/systemctl --no-pager status cyclestreets2
cyclestreets ALL = (root) NOPASSWD: /bin/systemctl status cyclestreets2
cyclestreets ALL = (root) NOPASSWD: /bin/systemctl start cyclestreets2
cyclestreets ALL = (root) NOPASSWD: /bin/systemctl stop cyclestreets2
cyclestreets ALL = (root) NOPASSWD: /bin/systemctl restart cyclestreets2

# Permit cyclestreets user to restart mysql, which is useful for resetting the configuration after an import run
cyclestreets ALL = (root) NOPASSWD: /bin/systemctl restart mysql
# Passwordless sudo to chown photomap files
cyclestreets ALL = (root) NOPASSWD: /opt/cyclestreets-setup/utility/chownPhotomapWwwdata.sh
# Passwordless sudo to remove coverage files at the start of an import run
cyclestreets ALL = (root) NOPASSWD: /opt/cyclestreets-setup/utility/removeCoverageCSV.sh
EOF

    # Make it read only
    chmod 440 ${csSudoers}
fi


echo "#	Completed installCommon"

# End of file
