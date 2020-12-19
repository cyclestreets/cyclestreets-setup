# Multipass

Create a CycleStreets website running in an Ubuntu virtual server on your host machine.

Download the [Multipass](https://multipass.run/) app for your OS to set up a mini-cloud on a laptop or desktop PC.

Update the `cyclestreets-setup` repo on your host and proceed as follows:


Making a custom copy of `cloud-config.yaml` file based on the [cloud-config.yaml.template](https://github.com/cyclestreets/cyclestreets-setup/blob/master/multipass/cloud-config.yaml.template) file.

	cd /opt/cyclestreets-setup/multipass
	cp cloud-config.yaml.template cloud-config.yaml
	pico -w cloud-config.yaml

Instantiate the virtual machine and setup the website:

	cd /opt/cyclestreets-setup/multipass
	./run.sh

The run file explains how to monitor progress and connect.


## VirtualBox


    sudo multipass set local.driver=virtualbox
