#!/bin/bash
# Installs a Mailman instance
# For Ubuntu 18.04 LTS


# Useful guides:
#   Ubuntu Mailman installation with Exim4: https://help.ubuntu.com/community/Mailman
#   General installation, though uses Postfix instead: https://www.howtoforge.com/how-to-install-and-configure-mailman-with-postfix-on-debian-squeeze
#   Mailman with Exim4: https://www.exim.org/howto/mailman21.html
#   Data migration from old server: https://debian-administration.org/article/567/Migrating_mailman_lists



# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#     This script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e


# 0. Obtain domain and confirm, e.g. lists.example.org should have argument example.org
if [ "$1" = "" ]; then
	echo "Usage: $0 example.org"
	exit
fi
domain=$1
echo "Creating a Mailman installation for lists.${domain}"

# 1. Apache
apt-get -y install apache2
# Copy in list config (if a customised version does not already exist)
if [ ! -f /etc/apache2/sites-available/lists.conf ]; then
	cp -pr lists.conf /etc/apache2/sites-available/
	sed -i "s/example.com/${domain}/g" /etc/apache2/sites-available/lists.conf
fi
a2ensite lists
a2enmod cgid
service apache2 restart

# 2. Exim4; see: https://help.ubuntu.com/community/Mailman#Exim4_Configuration
# NB this uses split configuration
apt-get -y install exim4
# Copy in Mailman files for Exim4
cp -pr 04_exim4-config_mailman /etc/exim4/conf.d/main/
sed -i "s/example.com/${domain}/g" /etc/exim4/conf.d/main/04_exim4-config_mailman
cp -pr 40_exim4-config_mailman /etc/exim4/conf.d/transport/
cp -pr 101_exim4-config_mailman /etc/exim4/conf.d/router/
# Set dc_use_split_config to true, and ensure dc_other_hostnames has the new listserver domain (lists.<domain>)
sed -i -r "s/dc_use_split_config.+/dc_use_split_config='true'/" /etc/exim4/update-exim4.conf.conf
# Add lists.example.com to dc_other_hostnames
if [ $(cat /etc/exim4/update-exim4.conf.conf | grep -c "lists.${domain}") -eq 0 ]; then
        sed -i -E "s/dc_other_hostnames='([^']+)'/dc_other_hostnames='\1:lists.${domain}'/" /etc/exim4/update-exim4.conf.conf
fi
update-exim4.conf
service exim4 restart
exim -bP '+local_domains'	# Verify config - should show the new listserver domain (lists.<domain>)

# 3. Mailman; see: https://www.exim.org/howto/mailman21.html#basic
apt-get -y install mailman
cp -pr mm_cfg.py /etc/mailman/
sed -i "s/example.com/${domain}/g" /etc/mailman/mm_cfg.py
newlist mailman
/usr/lib/mailman/bin/mailmanctl restart

# 4. Report how to import data from an old server
echo ""
echo "If you have an existing server, copy in the data as per the instructions at:"
echo "https://debian-administration.org/article/567/Migrating_mailman_lists"
echo "i.e."
echo "rsync -avz /usr/local/mailman/lists    root@new-server:/var/lib/mailman/"
echo "rsync -avz /usr/local/mailman/data     root@new-server:/var/lib/mailman/"
echo "rsync -avz /usr/local/mailman/archives root@new-server:/var/lib/mailman/"
echo ""


# Report completion
echo "#	Installing Mailman completed"

