#!/bin/bash
# mod_ja4
# See: https://github.com/szepeviktor/mod_ja4
# See: https://thumbprint.me/


# Ensure this script is run as root/sudo
if [ "$(id -u)" != "0" ]; then
	echo "#     This script must be run as root/sudo"
	exit 1
fi

# Bomb out if something goes wrong
set -e


# Install
if [ ! -f /usr/lib/apache2/modules/mod_ja4.so ]; then
	apt-get update
	apt-get install -y --no-install-recommends apache2 apache2-dev build-essential libssl-dev libtool-bin binutils
	wget -O /tmp/mod_ja4.zip https://github.com/szepeviktor/mod_ja4/archive/refs/tags/v0.1.1.zip
	unzip -d /tmp/ /tmp/mod_ja4.zip
	cd /tmp/mod_ja4-*
	make APXS=/usr/bin/apxs
	install -d -m 755 /usr/lib/apache2/modules
	apxs -i -S LIBEXECDIR=/usr/lib/apache2/modules mod_ja4.la
	strip --strip-unneeded /usr/lib/apache2/modules/mod_ja4.so
	echo -e '# Depends: ssl\nLoadModule ja4_module /usr/lib/apache2/modules/mod_ja4.so' > /etc/apache2/mods-available/ja4.load
	a2enmod ssl ja4
	service apache2 restart
	cd -
	rm -rf /tmp/mod_ja4*
fi
