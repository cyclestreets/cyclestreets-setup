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

# Munin
${ScriptHome}/utility/installMunin.sh

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

# Allow specific access to mysql from the dev machine
if [ -n "${devHostname}" ]; then

    # NAT64 - Network Address Translation between IP versions 6 and 4.
    # The dev machine is currently an IPv4 only host.
    # Servers that have IPv6 addresses are reached via NAT64 routers which provide mappings for IPv4.
    hasIPv6=`dig -t AAAA ${csHostname} +short`

    # MySQL authenticates connections with a reverse DNS lookup.
    # For those cases a reverse lookup of the IPv6 address resolves to the NAT64 router, rather than the dev machine.
    # To work around that problem a hard coded reverse lookup is added to /etc/hosts
    if [ -n "${hasIPv6}" -a -n "${devIPv6}" ]; then

	# Check it worked with:
	# getent hosts ${devHostname}
	#
	# If connections failed clear the cache by using: mysqladmin flush-hosts
	# or in the mysql client by running: flush hosts;
	# https://dev.mysql.com/doc/refman/8.0/en/problems-connecting.html
	echo -e "\n# The dev machine's IPv6 address via NAT64, needed for PhpMyAdmin added by CycleStreets live-deployment\n${devIPv6} ${devHostname}\n" >> /etc/hosts
    fi

    # Useful binding
    # The defaults-extra-file is a positional argument which must come first.
    superMysql="mysql --defaults-extra-file=${mySuperCredFile} -hlocalhost"
    ${superMysql} -e "drop user if exists 'root'@'${devHostname}';create user 'root'@'${devHostname}' identified with mysql_native_password by '${mysqlRootPassword}';grant all privileges on *.* to 'root'@'${devHostname}' with grant option;flush privileges;"
fi

# Install firewall
. ${ScriptHome}/utility/installFirewall.sh

# Confirm end of script
echo -e "#	All now deployed $(date)"

# End of file
