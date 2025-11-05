# Munin Node, which should be installed after all other software; see: https://www.digitalocean.com/community/tutorials/how-to-install-the-munin-monitoring-tool-on-ubuntu-14-04
# Include dependencies for Munin MySQL plugins; see: https://raymii.org/s/snippets/Munin-Fix-MySQL-Plugin-on-Ubuntu-12.04.html
apt install -y libcache-perl libcache-cache-perl

# Add libdbi-perl as otherwise /usr/share/munin/plugins/mysql_ suggest will show missing DBI.pm; see: http://stackoverflow.com/questions/20568836/cant-locate-dbi-pm and https://github.com/munin-monitoring/munin/issues/713
apt install -y libdbi-perl libdbd-mysql-perl

# Munin
apt install -y munin-node munin-plugins-extra

# Folders for munin plugin links and scripts
pLinks=/etc/munin/plugins/
pScripts=/usr/share/munin/plugins/

apiTransport=http
if [ -n "${useSSL}" ]; then
	apiTransport=https
fi
apiV2Url="${apiTransport}://${apiHostname}/v2/"

## CycleStreets Usage plugin
usageLink=${pLinks}cyclestreets
usageScript=${pScripts}cyclestreets
rm -f ${usageLink}
cp ${ScriptHome}/live-deployment/munin-cyclestreets.py ${usageScript}
sed -i "s|%apiV2Url|${apiV2Url}|g" ${usageScript}
sed -i "s|%apiKey|${testsApiKey}|g" ${usageScript}
ln -s ${usageScript} ${usageLink}

## Photomap Usage plugin
usageLink=${pLinks}photomap
usageScript=${pScripts}photomap
rm -f ${usageLink}
cp ${ScriptHome}/live-deployment/munin-photomap.py ${usageScript}
sed -i "s|%apiV2Url|${apiV2Url}|g" ${usageScript}
sed -i "s|%apiKey|${testsApiKey}|g" ${usageScript}
ln -s ${usageScript} ${usageLink}

## CycleStreets Journey Linger plugin
# If not provided use file based on hostname
if [ -z "${journeysLog}" ]; then
	journeysLog="${csHostname}-access.log"
fi
lingerLink=${pLinks}journeylinger
lingerScript=${pScripts}journeylinger
rm -f ${lingerLink}
cp ${ScriptHome}/live-deployment/cs-munin-journeylinger.sh ${lingerScript}
sed -i "s|\${ScriptHome}|${ScriptHome}|g" ${lingerScript}
sed -i "s|\${mySuperCredFile}|${mySuperCredFile}|g" ${lingerScript}
sed -i "s|\${websitesLogsFolder}|${websitesLogsFolder}|g" ${lingerScript}
sed -i "s|\${journeysLog}|${journeysLog}|g" ${lingerScript}
ln -s ${lingerScript} ${lingerLink}


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

# See: https://guide.munin-monitoring.org/en/latest/reference/munin-node-configure.html?highlight=configure
munin-node-configure --suggest --shell | sh

# Grant access to munin
if [ -n "${allowMunin}" ]; then
    echo -e "\n# Grant access from munin monitoring server\n${allowMunin}\n" >> /etc/munin/munin-node.conf
fi

systemctl restart munin-node
echo "Munin plugins enabled as follows:"
munin-node-configure --suggest | true
# If this doesn't seem to result in output, check this log file: `tail -f /var/log/munin/munin-node.log`
