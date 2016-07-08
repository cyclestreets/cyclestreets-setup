#!/bin/bash
# Script to deploy CycleStreets on Ubuntu
# Written for Ubuntu Server 16.04 LTS (View Ubuntu version using 'lsb_release -a')
# This script is idempotent - it can be safely re-run without destroying existing data

echo "#	CycleStreets live deployment $(date)"

# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#	This script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The second single line solution from that page is probably good enough as it is unlikely that this script itself will be symlinked.
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Use this to remove the ../
ScriptHome=$(readlink -f "${DIR}/..")

# Name of the credentials file
configFile=${ScriptHome}/.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x ${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist or is not excutable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. ${configFile}

# Load helper functions
. ${ScriptHome}/utility/helper.sh

# Main body of script

# Install the website
## !! Turned off for testing
#. ../install-website/run.sh

# SSL for secure logins
apt-get -y install openssl libssl1.0.0 libssl-dev
## !! TODO: Copy in SSL certificate files and add to VirtualHost config

# SSL is installed by default, but needs enabling
a2enmod ssl
service apache2 restart

# Enable support for proxied sites
a2enmod proxy_http
service apache2 restart

# MySQL configuration
mysqlConfFile=/etc/mysql/conf.d/cyclestreets.cnf
if [ ! -r ${mysqlConfFile} ]; then

    # Create the file (avoid any backquotes in the text as they'll spawn sub-processes)
    cat > ${mysqlConfFile} <<EOF
# MySQL Configuration for live server
# This config should be loaded via a symlink from: /etc/mysql/conf.d/
# On systems running apparmor the symlinks need to be enabled via /etc/apparmor.d/usr.sbin.mysqld

# Main characteristics
# * Concurrency
# * Responsiveness

# On some versions of mysql any *.cnf files that are world-writable are ignored.

[mysqld]

# Most CycleStreets tables use MyISAM storage
default-storage-engine = myisam
default_tmp_storage_engine = myisam

# Query Cache - on demand and best to limit to small efficient size
query_cache_type        = 2
query_cache_size        = 20M
EOF

    # Allow the user to edit this file
    chown ${username}:${rollout} ${mysqlConfFile}
fi

# Advise
echo "#	MySQL configured, but consider running the following security step from the command line: mysql_secure_installation"

# Restart mysql - as setup for passwordless sudo by the installer.
echo "#	$(date)	Restarting MySQL"
sudo service mysql restart

# Munin Node, which should be installed after all other software; see: https://www.digitalocean.com/community/tutorials/how-to-install-the-munin-monitoring-tool-on-ubuntu-14-04
# Include dependency for Munin MySQL plugins; see: https://raymii.org/s/snippets/Munin-Fix-MySQL-Plugin-on-Ubuntu-12.04.html
apt-get install -y libcache-perl libcache-cache-perl
# Add libdbi-perl as otherwise /usr/share/munin/plugins/mysql_ suggest will show missing DBI.pm; see: http://stackoverflow.com/questions/20568836/cant-locate-dbi-pm
apt-get install -y libdbi-perl
apt-get install -y munin-node
apt-get install -y munin-plugins-extra
ln -s /opt/cyclestreets-setup/live-deployment/cs-munin.sh /etc/munin/plugins/cyclestreets
# See: http://munin-monitoring.org/wiki/munin-node-configure
munin-node-configure --suggest --shell | sh
#!# MySQL 5.7 doesn't seem to work; gives error "Wrong amount of autoconf"; reported at: https://github.com/munin-monitoring/munin/issues/713
/etc/init.d/munin-node restart
echo "Munin plugins enabled as follows:"
munin-node-configure --suggest

# Cron jobs - note the timings of these should be the same as in the fromFallback.sh
if $installCronJobs ; then

    # Update scripts
    installCronJob ${username} "25 6 * * * cd ${ScriptHome} && git pull -q"

    # Dump data every day at 1:01 am
    # Choose a timing that allows the script to complete before being polled by the automatic testing - which currently (April 2015) happens on each five minute boundary
    installCronJob ${username} "1 1 * * * ${ScriptHome}/live-deployment/daily-dump.sh"

    # Hourly zapping at 13 mins past every hour
    installCronJob ${username} "13 * * * * ${ScriptHome}/utility/remove-tempgenerated.sh"

    # Install routing data, using quiet option to suppress advice messages
    # A time in the middle of the day is probably best overall as likely to be awake to handle any issues.
    # Experience has shown that doing it in the middle of the night is likely to lead to ping messages caused by temporary routing test failures due to the heavy i/o.
    installCronJob ${username} "34 11 * * * ${ScriptHome}/live-deployment/install-routing-data.sh -q"
fi

# Confirm end of script
echo -e "#	All now deployed $(date)"

# End of file
