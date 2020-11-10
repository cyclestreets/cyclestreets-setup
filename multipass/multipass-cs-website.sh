#!/bin/bash

# Announce
echo -e "#\tStarting setting up a CycleStreets website in a Multipass instance."


### CREDENTIALS ###

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The second single line solution from that page is probably good enough as it is unlikely that this script itself will be symlinked.
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Use this to remove the ../
#ScriptHome=$(readlink -f "${DIR}/..")
# Above doesn't work on Mac so skip
ScriptHome=${DIR}

# Change to the script's folder
cd ${ScriptHome}

# Name of the credentials file
configFile=${ScriptHome}/.config.sh

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x ${configFile} ]; then
    echo "#	The config file, ${configFile}, does not exist or is not excutable. Copy your own based on the ${configFile}.template file, or create a symlink to the configuration."
    exit 1
fi

# Load the credentials
. ${configFile}


# Abandon on error
set -e

# Clone the cyclestreets-setup repo
git clone https://github.com/cyclestreets/cyclestreets-setup.git
git config -f cyclestreets-setup/.git/config core.sharedRepository group
chgrp -R rollout cyclestreets-setup
sudo mv cyclestreets-setup /opt/cyclestreets-setup

# Move config from it's temporary home
mv cyclestreets-setup.config.sh /opt/cyclestreets-setup/.config.sh

# Install the website
sudo /opt/cyclestreets-setup/install-website/run.sh

# Install the import system
#sudo /opt/cyclestreets-setup/install-import/run.sh

# Build a new routing edition
#sudo -u cyclestreets /opt/cyclestreets-setup/newbuild.sh /websites/www/content/import/.config.php

echo -e "# Finished setting up the CS website in a Multipass instance."

# End of file
