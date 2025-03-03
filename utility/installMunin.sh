# Munin Node, which should be installed after all other software; see: https://www.digitalocean.com/community/tutorials/how-to-install-the-munin-monitoring-tool-on-ubuntu-14-04
# Include dependencies for Munin MySQL plugins; see: https://raymii.org/s/snippets/Munin-Fix-MySQL-Plugin-on-Ubuntu-12.04.html
apt install -y libcache-perl libcache-cache-perl

# Add libdbi-perl as otherwise /usr/share/munin/plugins/mysql_ suggest will show missing DBI.pm; see: http://stackoverflow.com/questions/20568836/cant-locate-dbi-pm and https://github.com/munin-monitoring/munin/issues/713
apt install -y libdbi-perl libdbd-mysql-perl

# Munin
apt install -y munin-node munin-plugins-extra

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
munin-node-configure --suggest | true
# If this doesn't seem to result in output, check this log file: `tail -f /var/log/munin/munin-node.log`
