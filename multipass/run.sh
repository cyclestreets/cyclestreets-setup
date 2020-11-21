#!/bin/bash

# Announce
echo -e "#\tSet up CycleStreets website running in a Multipass instance."


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

# Abandon on failure
set -e

# Load the credentials
. ${configFile}


### DEFAULTS ###

# Public Key - can be given via path
if [ -n "${your_public_key_path}" ]; then
    your_public_key=$(cat ${your_public_key_path})
fi
if [ -z "${your_public_key}" ]; then
    echo -e "#\tNo public key provided.";
    exit 1
fi

# Ensure Name
if [ -z "${your_login_name}" ]; then
    your_login_name=$USER
fi

# Ensure Gecos
if [ -z "${your_login_gecos}" ]; then
    your_login_gecos=$(id -F)
fi


### Main body ###

# Remove any entry in the known hosts for this VM.
# This is likely during development when new VMs are constantly being built and tested.
ssh-keygen -R ${vm_name}

# Make a copy from the config template (overwriting any existing one)
cp -p ${vm_cloud_init}.template ${vm_cloud_init}

# Setup the configuration
if grep CONFIGURED_BY_HERE ${vm_cloud_init} >/dev/null 2>&1;
then

    # Make the substitutions
    echo "#	Configuring ${vm_cloud_init}"

    # On Mac OS the zero length extension to the -i option should be explicitly provided (otherwise it uses the -e)
    sed -i "" -e "s|CONFIGURED_BY_HERE|Configured by CycleStreets Multipass setup $(date)|" \
	-e "s|YOUR_LOGIN_NAME|${your_login_name}|" \
	-e "s|YOUR_LOGIN_GECOS|${your_login_gecos}|" \
	-e "s|YOUR_PUBLIC_KEY|${your_public_key}|" \
	-e "s|CYCLESTREETS_LOGIN_NAME|${cyclestreets_login_name}|" \
	-e "s|CYCLESTREETS_LOGIN_GECOS|${cyclestreets_login_gecos}|" \
	-e "s|CYCLESTREETS_LOGIN_PASSWD|${cyclestreets_login_passwd}|" \
    ${vm_cloud_init}
fi

# Launch the virtual machine
multipass launch \
	  --name ${vm_name} \
	  --cpus ${vm_cpus} \
	  --mem ${vm_mem} \
	  --disk ${vm_disk} \
	  --cloud-init ${vm_cloud_init}

# What ssh port was opened?
multipass_vm_ip=$(multipass info ${vm_name} | grep 'IPv4' | awk '{print $2}')

# Advise
echo -e "#\tCycleStreets Multipass Instance"
echo -e "#\t-------------------------------"
echo -e "#\tConnect:\n#\t\tssh ${multipass_vm_ip}\n#\tAlias:\n#\t\tssh ${vm_name}"
echo -e "#\tClearup:\n#\t\tmultipass stop ${vm_name} && multipass delete ${vm_name} && multipass purge"


## Configure the instance to install a CycleStreets website

# Create folder
multipassFolder=/home/${USER}/multipass
multipass exec ${vm_name} -- sudo su - ${USER} -c "mkdir -p ${multipassFolder}"

# Copy user's github credentials - which should include a token that allows passwordless access
scp -o "StrictHostKeyChecking no" ~/.gitconfig ${vm_name}:~

# Copy the creation script (should not require a password)
scp -o "StrictHostKeyChecking no" /opt/cyclestreets-setup/multipass/.config.sh ${vm_name}:${multipassFolder}
scp -o "StrictHostKeyChecking no" /opt/cyclestreets-setup/multipass/multipass-cs-website.sh ${vm_name}:${multipassFolder}

# Copy cyclestreets-setup configuration to temporary location
scp -o "StrictHostKeyChecking no" ${cyclestreetsSetupConfig} ${vm_name}:${multipassFolder}/cyclestreets-setup.config.sh

# Run the installation as the login user
multipass exec ${vm_name} -- sudo su - ${USER} -c "${multipassFolder}/multipass-cs-website.sh"


# Add as alias in hosts file
# sudo bash -c 'echo -e "#\tMultipass VM\n${multipass_vm_ip}\t${vm_name} api-${vm_name}" >> /etc/hosts'
echo -e "#\tAdd the following lines to your local: /etc/hosts\n\n#\tMultipass Virtual Machine\n${multipass_vm_ip}\t${vm_name} api-${vm_name}\n"


# Announce
echo -e "#\tThe CycleStreets website should now be available on your Multipass instance at http://${vm_name}/"

# End of file
