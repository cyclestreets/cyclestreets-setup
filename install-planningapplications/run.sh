#!/bin/bash
# Script to install planning applications module

# Ensure this script is not run as root
if [ "$(id -u)" == "0" ]; then
    echo "#	This script must not be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e


# Main body
# Announce starting
echo "#	CycleStreets planning applications module installation $(date)"

# Useful bindings
# The defaults-extra-file is a positional argument which must come first.
superMysql="mysql --defaults-extra-file=${mySuperCredFile} -hlocalhost"
externalDb=csExternal

# Add privileges
$superMysql -e "GRANT SELECT, INSERT, UPDATE, ALTER ON ${externalDb}.planningapplications TO website@localhost;";

# Add cron job
cp /opt/cyclestreets-setup/install-planningapplications/cyclestreets-planningapplications.cron /etc/cron.d/cyclestreets-planningapplications
chown root.root /etc/cron.d/cyclestreets-planningapplications
chmod 0600 /etc/cron.d/cyclestreets-planningapplications


# Done
echo "#	Planning applications module requirements installed successfully."

# Indicate success
:

# End of file
