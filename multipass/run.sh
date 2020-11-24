#!/bin/bash

# Announce
echo -e "#\tSet up CycleStreets website running in a Multipass instance."

# Abandon on error
set -e

### DEFAULTS ###

# Name of the Multipass instance (appears to be limited to alphanumeric and hyphen, no dots)
vm_name=cs-multipass
vm_cpus=2
vm_mem=4g
vm_disk=20g
vm_cloud_init=cloud-config.yaml

# Get the script directory see: http://stackoverflow.com/a/246128/180733
# The second single line solution from that page is probably good enough as it is unlikely that this script itself will be symlinked.
DIR="$( cd -P "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Use this to remove the ../
#ScriptHome=$(readlink -f "${DIR}/..")
# Above doesn't work on Mac so skip
ScriptHome=${DIR}

# Change to the script's folder
cd ${ScriptHome}

### Main body ###

# Remove any entry in the known hosts for this VM.
# This is likely during development when new VMs are constantly being built and tested.
ssh-keygen -R ${vm_name}

# Launch the virtual machine
multipass launch \
	  --name ${vm_name} \
	  --cpus ${vm_cpus} \
	  --mem ${vm_mem} \
	  --disk ${vm_disk} \
	  --cloud-init ${vm_cloud_init}

# Note: the clout-init run scripts may take longer than five minutes to run in which case the above announces that:
#   launch failed: The following errors occurred:
#   timed out waiting for initialization to complete
# But in fact those scripts are still running. This is a known problem with multipass:
# https://github.com/canonical/multipass/issues/1039

# Because of the timeout the following messages may not be displayed:

# What ssh port was opened?
multipass_vm_ip=$(multipass info ${vm_name} | grep 'IPv4' | awk '{print $2}')

# Advise
echo -e "#\tCycleStreets Multipass Instance"
echo -e "#\t-------------------------------"
echo -e "#\tConnect:\n#\t\tssh ${multipass_vm_ip}\n#\tAlias:\n#\t\tssh ${vm_name}"
echo -e "#\tClearup:\n#\t\tmultipass stop ${vm_name} && multipass delete ${vm_name} && multipass purge"

# Progress of the installation can be tracked at:
# /ssh:${vm_name}:/var/log/cloud-init-output.log
