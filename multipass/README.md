# Multipass

Create a CycleStreets website running in an Ubuntu virtual server on your host machine.

Download the [Multipass](https://multipass.run/) app for your OS to set up a mini-cloud on a laptop or desktop PC.

Update the `cyclestreets-setup` repo on your host and proceed as follows:



Making a custom copy of `cloud-config.yaml` file based on the [cloud-config.yaml.template](https://github.com/cyclestreets/cyclestreets-setup/blob/master/multipass/cloud-config.yaml.template) file.

	cd /opt/cyclestreets-setup/multipass
	cp .config.sh.template .config.sh
	pico -w .config.sh
	cp cloud-config.yaml.template cloud-config.yaml
	pico -w cloud-config.yaml

Instantiate the virtual machine and setup the website:

	cd /opt/cyclestreets-setup
	multipass/run.sh .config.sh

The run file explains how to monitor progress and connect.


## Troubleshooting

The apache error log may show messages like:

    PHP Warning:  file_get_contents(): Failed to open stream: php_network_getaddresses: getaddrinfo for ... failed: Temporary failure in name resolution in ....

when the server tries to call the API, as happens from the `/tests/` and `/routing.html` pages.
If so check that both the cs host name and api host name have entries in `/etc/hosts`.
These should have been set during the `install-website` script.
