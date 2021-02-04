#!/bin/bash
# Set up CycleStreets website running in a Multipass instance.

usage()
{
    cat << EOF

SYNOPSIS
	$0 -h config

OPTIONS
	-h Show this message

ARGUMENTS
	config
		Configuration file

DESCRIPTION
	Set up CycleStreets website running in a Multipass instance.

EOF
}


# http://wiki.bash-hackers.org/howto/getopts_tutorial
# An opening colon in the option-string switches to silent error reporting mode.
# Colons after letters indicate that those options take an argument e.g. m takes an email address.
while getopts "h" option ; do
    case ${option} in
        h) usage; exit ;;
	\?) echo "Invalid option: -$OPTARG" >&2 ; exit ;;
    esac
done

# After getopts is done, shift all processed options away with
shift $((OPTIND-1))

# Check required arguemnt
if [ -z "$1" ]; then
    echo "#	$0 Error: no config argument" 1>&2
    exit 1
fi
configFile=$1

# Abandon on error
set -e


### CREDENTIALS ###

# Generate your own credentials file by copying from .config.sh.template
if [ ! -x ${configFile} ]; then
    echo -e "#\tThe config file, ${configFile}, does not exist or is not executable. Copy your own based on the .config.sh.template file, or create a symlink to the configuration."
    exit 1
fi

# Load the credentials
. ${configFile}


### Main body ###

# Advise
echo -e "#\tCycleStreets Multipass Instance"
echo -e "#\t-------------------------------"

# Use hyperkit as the hypervisor
#sudo multipass get local.driver
#sudo multipass set local.driver=hyperkit

# Remove any entry in the known hosts for this VM.
# This is likely during development when new VMs are frequently built and tested.
# It is most helpful to do this before the launch has completed so the developer does not
# get prompted for confirmation when logging in to monitor progress.
echo -e "#\tRemove cached known_host entries if they exist:"
ssh-keygen -R ${vm_name}
ssh-keygen -R ${vm_name}.cyclestreets.net

# Advise
echo -e "#\n#\tLaunching Ubuntu ${ubuntuImage}..."

# Check progress on the vm using:
echo -e "#\n# Monitor progress"
echo -e "#\n#\tAfter 'Starting ...' changes to 'Waiting ...' progress on the vm can be checked using:"
echo -e "#\t${USER}@${vm_name}:~$ less +F /var/log/cloud-init-output.log"

# Note: the cloud-init run scripts may take longer than five minutes to run in which case the above announces that:
#   launch failed: The following errors occurred:
#   timed out waiting for initialization to complete
# But in fact those scripts are still running. This is a known problem with multipass:
# https://github.com/canonical/multipass/issues/1039
echo -e "#\n# Timeout"
echo -e "#\tIf the following message is displayed:"
echo -e "#\t\tlaunch failed: The following errors occurred:"
echo -e "#\t\ttimed out waiting for initialization to complete"
echo -e "#\tthen in fact the script may still be running, and this a problem known to the multipass developers."

# How to connect
echo -e "#\n# Connect\n#\tThe ip address of the vm is available only after launch but is usually the same each time. Use:"
echo -e "#\tmultipass info ${vm_name} | grep IPv4\n#\n# Alias (when set in .ssh/config):\n#\tssh ${vm_name}"
echo -e "#\n# Clearup:\n#\tmultipass stop ${vm_name} && multipass delete ${vm_name} && multipass purge"

# Website
echo -e "#\n# Website:\n#\thttp://${vm_name}/"


# Launch the virtual machine
multipass launch --verbose \
	  --name $vm_name \
	  --cpus $vm_cpus \
	  --mem $vm_mem \
	  --disk $vm_disk \
	  --cloud-init $vm_cloud_init $ubuntuImage

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

# Launches can fail if a previous instance got stuck for some unknown reason.
# Advice from: https://github.com/machine-drivers/docker-machine-driver-xhyve/issues/107 suggests:
# Find their processes using e.g:
# ps aux | grep multipass
# Stop the process using e.g:
# kill -9 <pid>
# and try again.

# This seems to be a way of restarting the multipass daemon on MacOS:
# sudo launchctl kickstart -k system/com.canonical.multipassd

# End of file
