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

# List available images using: multipass find
ubuntuImage=18.04

### Main body ###

# Remove any entry in the known hosts for this VM.
# This is likely during development when new VMs are constantly being built and tested.
ssh-keygen -R ${vm_name}

# Launch the virtual machine
multipass launch --verbose \
	  --name ${vm_name} \
	  --cpus ${vm_cpus} \
	  --mem ${vm_mem} \
	  --disk ${vm_disk} \
	  --cloud-init ${vm_cloud_init} {$ubuntuImage}

echo -e "#\tLaunch completed."

# Note: the cloud-init run scripts may take longer than five minutes to run in which case the above announces that:
#   launch failed: The following errors occurred:
#   timed out waiting for initialization to complete
# But in fact those scripts are still running. This is a known problem with multipass:
# https://github.com/canonical/multipass/issues/1039

# Because of the timeout the following messages may not be displayed:

# Determine the ip address of the instantiated virtual machine
# https://multipass.run/docs/troubleshooting-networking-on-macos
multipass_vm_ip=$(multipass info ${vm_name} | grep 'IPv4' | awk '{print $2}')

# Advise
echo -e "#\tCycleStreets Multipass Instance"
echo -e "#\t-------------------------------"
echo -e "#\tConnect:\n#\t\tssh ${multipass_vm_ip}\n#\tAlias:\n#\t\tssh ${vm_name}"
echo -e "#\tClearup:\n#\t\tmultipass stop ${vm_name} && multipass delete ${vm_name} && multipass purge"

# Progress of the installation can be tracked at:
# /ssh:${vm_name}:/var/log/cloud-init-output.log
