#!/bin/bash
# Script to deploy CycleStreets on Ubuntu
# Tested on 12.10 (View Ubuntu version using 'lsb_release -a')
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

# General options as recommended by
# http://www.percona.com/pdf-canonical-header?path=files/presentations/percona-live/dc-2012/PLDC2012-optimizing-mysql-configuration.pdf
# mysqltuner
# select @@thread_cache_size, @@table_open_cache, @@open_files_limit;
thread_cache_size = 100
table_open_cache = 4096
open_files_limit = 65535

# This should be set to about 20 - 50% of available memory. On our 8GB www machine a good size is probably 1G. (The default is only 16M is a performance killer.)  
key_buffer		= 2G

max_allowed_packet	= 16M
group_concat_max_len	= 50K

# Query Cache - on demand
query_cache_type        = 2
# These are quite big
query_cache_limit	= 1M
query_cache_size        = 50M

# Useful for performance monitoring
log_slow_queries	= /var/log/mysql/mysql-slow.log
long_query_time = 2
# Enable this only for a session focussing on performance enhancement
# log_queries_not_using_indexes = 1

# CHARACTER SET
# It is simplest (and quickest, due to no translation overhead) if all text uses the utf8 character set and collation utf8_unicode_ci (case-insensitive).
# Set these in the mysql server configuration so that the osmosis program which reads the OpenStreetMap planet extracts also uses this character set.

# Set default character set and collation
character_set_server=utf8
collation_server=utf8_unicode_ci
EOF

    # Allow the user to edit this file
    chown ${username}:rollout ${mysqlConfFile}
fi


# Advise
echo "#	MySQL configured, but consider running the following security step from the command line: mysql_secure_installation"

# Cron jobs
if $installCronJobs ; then

    # Update scripts
    jobs[1]="25 6 * * * cd ${ScriptHome} && git pull -q"

    # Dump data every day at 4:04 am
    jobs[2]="4 4 * * * ${ScriptHome}/live-deployment/daily-dump.sh"

    # Hourly zapping at 13 mins past every hour
    jobs[3]="13 * * * * ${ScriptHome}/utility/remove-tempgenerated.sh"

    # Install routing data at 34 mins past every hour in the small hours
    jobs[4]="34 1,2,3,4 * * * ${ScriptHome}/live-deployment/install-routing-data.sh"

    # Install the jobs
    installCronJobs ${username} jobs[@]
fi

# Confirm end of script
echo -e "#	All now deployed $(date)"

# End of file
