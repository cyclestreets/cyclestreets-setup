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
    echo "#	The config file, ${configFile}, does not exist or is not executable - copy your own based on the ${configFile}.template file." 1>&2
    exit 1
fi

# Load the credentials
. ${configFile}

# Main body of script

# Install the website
${ScriptHome}/install-website/run.sh

# Enable support for proxied sites
a2enmod proxy_http
systemctl restart apache2

# Helper to add cron job for automatic updating of a repo
# Argument is of the form: /path/to/{reponame}-update.cron
function addCronRepoUpdater {
    local repoUpdateCronPath=$1
    local repoUpdateCronName=`basename ${repoUpdateCronPath}`
    # Remove .cron from the end
    local repoUpdateName=${repoUpdateCronName:0:-5}
    local cronFile=/etc/cron.d/${repoUpdateName}
    cp -pr ${repoUpdateCronPath} $cronFile
    chown root.root $cronFile
    chmod 0600 $cronFile
}

# Add cron jobs for automatic updating of the site and setup repo
if [ -n "${repoUpdateCronPaths}" ]; then
    for i in ${repoUpdateCronPaths[@]}; do
	addCronRepoUpdater ${i}
    done
fi


# Munin Node, which should be installed after all other software; see: https://www.digitalocean.com/community/tutorials/how-to-install-the-munin-monitoring-tool-on-ubuntu-14-04
# Include dependencies for Munin MySQL plugins; see: https://raymii.org/s/snippets/Munin-Fix-MySQL-Plugin-on-Ubuntu-12.04.html
apt install -y libcache-perl libcache-cache-perl
# Add libdbi-perl as otherwise /usr/share/munin/plugins/mysql_ suggest will show missing DBI.pm; see: http://stackoverflow.com/questions/20568836/cant-locate-dbi-pm and https://github.com/munin-monitoring/munin/issues/713
apt install -y libdbi-perl libdbd-mysql-perl
apt install -y munin-node
apt install -y munin-plugins-extra

# Symlink the cyclestreets charts, clearing away any old ones first
rm -f /etc/munin/plugins/cyclestreets
ln -s /opt/cyclestreets-setup/live-deployment/cs-munin.sh /etc/munin/plugins/cyclestreets
rm -f /etc/munin/plugins/journeylinger
ln -s /opt/cyclestreets-setup/live-deployment/cs-munin-journeylinger.sh /etc/munin/plugins/journeylinger

# Some specific Plugins
if [ -f /etc/munin/plugins/dnsresponsetime ]; then
	wget -P /usr/share/munin/plugins/ --user-agent="Foo" http://ccgi.ambrosia.plus.com/debian/dnsresponsetime
	chmod +x /usr/share/munin/plugins/dnsresponsetime
	ln -s /usr/share/munin/plugins/dnsresponsetime /etc/munin/plugins
fi
if [ -f /etc/munin/plugins/packetloss ]; then
	wget -P /usr/share/munin/plugins/ https://raw.githubusercontent.com/munin-monitoring/contrib/master/plugins/network/packetloss
	chmod +x /usr/share/munin/plugins/packetloss
	ln -s /usr/share/munin/plugins/packetloss /etc/munin/plugins
	echo '[packetloss_*]' >> /etc/munin/plugin-conf.d/munin-node
	echo 'timeout 60'     >> /etc/munin/plugin-conf.d/munin-node
	echo 'user root'      >> /etc/munin/plugin-conf.d/munin-node
fi
# See: http://munin-monitoring.org/wiki/munin-node-configure
munin-node-configure --suggest --shell | sh

# Grant access to munin
if [ -n "${allowMunin}" ]; then
    echo -e "\n# Grant access from munin monitoring server\n${allowMunin}\n" >> /etc/munin/munin-node.conf
fi

systemctl restart munin-node
echo "Munin plugins enabled as follows:"
set +e
munin-node-configure --suggest
# If this doesn't seem to result in output, check this log file: `tail -f /var/log/munin/munin-node.log`


## PhpMyAdmin
# Note: as of 8.0.13 this can become a csv of addresses such as: 127.0.0.1,::1,dev.cyclestreets.net
# Unless already setup
mysqldcnfFile=/etc/mysql/mysql.conf.d/mysqld.cnf
if [ -r $mysqldcnfFile ] && ! cat $mysqldcnfFile | grep "^#bind-address" > /dev/null 2>&1
then
    # Comment out to allow access from anywhere and restart mysql
    sed -i '/^bind-address/s/^/#/' $mysqldcnfFile
    systemctl restart mysql
fi

# Allow specific access from the dev machine
if [ -n "${devHostname}" ]; then
    # The dev machine is currently an IPv4 only host.
    # When accessing using IPv6 then reverse DNS needs setup to verify the dev hostname.
    # Check with:
    # getent hosts ${devHostname}
    #
    # If connections failed clear the cache by using: mysqladmin flush-hosts
    # https://dev.mysql.com/doc/refman/8.0/en/problems-connecting.html
    if [ -n "${devIPv6}" ]; then
	echo -e "\n# The dev machine's IPv6 address via NAT64, added by cloud-init\n${devIPv6} ${devHostname}\n" >> /etc/hosts
    fi
    # Useful binding
    # The defaults-extra-file is a positional argument which must come first.
    superMysql="mysql --defaults-extra-file=${mySuperCredFile} -hlocalhost"
    ${superMysql} -e "drop user if exists 'root'@'${devHostname}';create user 'root'@'${devHostname}' identified with mysql_native_password by '${mysqlRootPassword}';grant all privileges on *.* to 'root'@'${devHostname}' with grant option;flush privileges;"
fi

# Confirm end of script
echo -e "#	All now deployed $(date)"

# End of file
