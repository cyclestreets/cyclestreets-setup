# Sections of script that are common to install-website and install-import


# Add the path to content (the -p option creates the intermediate www)
mkdir -p ${websitesContentFolder}

# Switch to content folder
cd ${websitesContentFolder}

# Create/update the CycleStreets repository, ensuring that the files are owned by the CycleStreets user (but the checkout should use the current user's account - see http://stackoverflow.com/a/4597929/180733 )
if [ ! -d ${websitesContentFolder}/.git ]
then
    ${asCS} git clone https://github.com/cyclestreets/cyclestreets.git ${websitesContentFolder}
else
    ${asCS} git pull
fi

# Ensure there's a custom sudoers file
if [ -n "${csSudoers}" -a ! -e "${csSudoers}" -a -n "${routingDaemonLocation}" ]; then

    # !! Potentially add more checks to the variables used in these sudoers expressions, such as ensuring the variables are full paths to the commands.

    # Create file that provides passwordless sudo access to the routing service - which needs root access to control running service
    # A number of other passwordless options are also included when operating in a variety of roles such as doing imports or running backup / restores.
    cat > ${csSudoers} << EOF
# Permit cyclestreets user to control the routing service without a password
cyclestreets ALL = (root) NOPASSWD: /bin/systemctl --no-pager status cycleroutingd
cyclestreets ALL = (root) NOPASSWD: /bin/systemctl status cycleroutingd
cyclestreets ALL = (root) NOPASSWD: /bin/systemctl start cycleroutingd
cyclestreets ALL = (root) NOPASSWD: /bin/systemctl stop cycleroutingd
cyclestreets ALL = (root) NOPASSWD: /bin/systemctl restart cycleroutingd
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
