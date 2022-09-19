#!/bin/bash
# Firewall (UFW)


# Ensure this script is run as root/sudo
if [ "$(id -u)" != "0" ]; then
	echo "#     This script must be run as root/sudo"
	exit 1
fi

# Bomb out if something goes wrong
set -e


# Install UFW
apt-get -y install ufw
ufw logging low
ufw --force reset
ufw --force enable
ufw default deny


# SSH
ufw allow ssh

# Webserver
ufw allow http
ufw allow https

# Munin-node, accessible only from dev
ufw allow from 127.0.0.1 to any port 4949
ufw allow from 46.235.226.213 to any port 4949

# MySQL, if present
if [ -d /var/lib/mysql/ ]; then
	ufw allow from 127.0.0.1 to any port 3306
	ufw allow from 46.235.226.213 to any port 3306
fi

# Incoming mail processing, on dev
if [ -f /etc/aliases ]; then
	if grep -q "info:" /etc/aliases ; then
		ufw allow 25
	fi
fi

# Photon, if present
if [ -d /opt/photon/ ]; then
	ufw allow 2322
fi

# Routing engine, if present
if [ -d /websites/www/content/routingengine/ ]; then
	ufw allow 9000		# Main
	ufw allow 9001		# Secondary
fi


# Reload
ufw reload
ufw status verbose

# Set UFW logging to be done only into /var/log/ufw.log rather than into /var/log/syslog
sed -i 's/#\& ~/\& stop/g' /etc/rsyslog.d/20-ufw.conf
service rsyslog restart

