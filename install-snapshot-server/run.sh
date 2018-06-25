#!/bin/bash
# Installs the snapshot server software
# For Ubuntu 14.04 LTS
# See: https://github.com/cyclestreets/snapshot-server/


# Ensure this script is run as root
if [ "$(id -u)" != "0" ]; then
    echo "#     This script must be run as root." 1>&2
    exit 1
fi

# Bomb out if something goes wrong
set -e

# Lock directory
lockdir=/var/lock/snapshot
mkdir -p $lockdir

# Set a lock file; see: http://stackoverflow.com/questions/7057234/bash-flock-exit-if-cant-acquire-lock/7057385
(
	flock -n 9 || { echo '#	An installation is already running' ; exit 1; }

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The multi-line method of geting the script directory is needed because this script is likely symlinked from cron
SOURCE="${BASH_SOURCE[0]}"
DIR="$( dirname "$SOURCE" )"
while [ -h "$SOURCE" ]
do
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
  DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
SCRIPTDIRECTORY=$DIR


## Main body

# Update system to a fully-patched state
apt-get update
apt-get -y upgrade
apt-get -y dist-upgrade
apt-get -y autoremove

# Install Ruby (1.9.3)
apt-get -y install ruby ruby-dev
apt-get -y install libxml2-dev libxslt-dev

# Install PostgreSQL
apt-get -y install postgresql-9.3 postgresql-server-dev-9.3 postgresql-9.3-postgis-2.1 postgresql-contrib-9.3
apt-get -y install postgresql-client-9.3

# Install bundler
apt-get -y install bundler

# Create a user for Postgres
username=snapshot
password=`date +%s | sha256sum | base64 | head -c 32 ; echo`
if id -u ${username} >/dev/null 2>&1; then
	echo "# User ${username} exists already and will be used."
else
	useradd -m $username
	echo "${username}:${password}" | /usr/sbin/chpasswd
	usermod -a -G snapshot $username
fi

# Shortcut for running commands as the snapshot user
asCS="sudo -u ${username}"

# Define site location if not defined by a calling script
if [ -z "${snapshotContentFolder+x}" ]; then
	snapshotContentFolder=/var/www/snapshot
fi

# Create/update the repository, ensuring that the files are owned by the user (but the checkout should use the current user's account - see http://stackoverflow.com/a/4597929/180733 )
if [ ! -d "${snapshotContentFolder}/.git" ]
then
	mkdir -p "${snapshotContentFolder}/"
	chown $username "${snapshotContentFolder}/"
        ${asCS} git clone https://github.com/cyclestreets/snapshot-server.git "${snapshotContentFolder}/"
else
        ${asCS} git -C "${snapshotContentFolder}" pull
fi

# Install the Gem dependencies; if there is a failure, tailing the noted log will usually indicate the missing software, or the Gemfile needs to have gems pinned to older Ruby
apt-get -y install make
cd "${snapshotContentFolder}/" && bundle install

# Create the databases
apt-get -y install rake
cp -pr $SCRIPTDIRECTORY/database.yml "${snapshotContentFolder}/config/database.yml"
sudo -u postgres psql postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='snapshot'" | grep -q 1 || sudo -u postgres createuser --createdb --superuser --no-createrole snapshot
$asCS bash -c "cd ${snapshotContentFolder}/ && RAILS_ENV=production rake db:create"
$asCS bash -c "cd ${snapshotContentFolder}/ && RAILS_ENV=production rake db:migrate"
#sudo -u postgres psql snapshot-prod -c "CREATE EXTENSION postgis;"

# Test at this stage using:
#   sudo -u $username bash -c "cd ${snapshotContentFolder}/ && rails server"

# Install Apache
apt-get -y install apache2

# Install Passenger (for serving Rails applications in Apache); see: https://www.phusionpassenger.com/library/install/apache/install/oss/precise/
apt-get -y install dirmngr gnupg
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7
apt-get install -y apt-transport-https ca-certificates
sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger trusty main > /etc/apt/sources.list.d/passenger.list'
apt-get update
apt-get -y install libapache2-mod-passenger
a2enmod passenger
apache2ctl restart

# Add the VirtualHost
vhConf=/etc/apache2/sites-available/snapshot.conf
if [ ! -f ${vhConf} ]; then
	cp -p $SCRIPTDIRECTORY/.apache-vhost.conf.template $vhConf
        sed -i "s|/var/www/snapshot|${snapshotContentFolder}|g" ${vhConf}
fi

# Enable the site
a2ensite snapshot
apache2ctl restart



# Remove the lock file - ${0##*/} extracts the script's basename
) 9>$lockdir/${0##*/}

