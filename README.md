# cyclestreets-setup

Scripts for installing CycleStreets, written for Ubuntu Server 16.04 LTS

**Note this is work-in-progress and the CycleStreets repo which is needed is not yet publicly available.**

## Requirements

Written for Ubuntu Server 16.04 LTS.
Earlier versions of scripts tested, March 2015 on a Ubuntu Server 14.04.2 LTS VM with 1 GB RAM, 8GB HD.

## Timezone

```shell
# Check your machine is in the right timezone
# user@machine:~$
cat /etc/timezone

# If not set it using:
sudo dpkg-reconfigure tzdata
```

## Setup

Add this repository to a machine using the following, as your normal username (not root). In the listing the grouped items can usually be cut and pasted together into the command shell, others require responding to a prompt:

```shell
# Install git
# user@machine:~$
sudo apt-get -y install git

# Tell git who you are
# git config --global user.name "Your git username"
# git config --global user.email "Your git email"
# git config --global push.default simple
# git config --global credential.helper 'cache --timeout=86400'

# Clone the cyclestreets-setup repo
git clone https://github.com/cyclestreets/cyclestreets-setup.git

# Move it to the right place
sudo mv cyclestreets-setup /opt
cd /opt/cyclestreets-setup/
git config core.sharedRepository group

# Create the cyclestreets user - without prompting for e.g. office 'phone number
sudo adduser --gecos "" cyclestreets

# Create the rollout group
sudo addgroup rollout

# Add your username to the rollout group
sudo adduser `whoami` rollout

# The adduser command above can't add your existing shell process to the
# new rollout group; you may want to replace it by doing:
exec newgrp rollout

# Set ownership and group
# user@machine:~$
sudo chown -R cyclestreets.rollout /opt/cyclestreets-setup

# Set group permissions and add sticky group bit
sudo chmod -R g+w /opt/cyclestreets-setup
sudo find /opt/cyclestreets-setup -type d -exec chmod g+s {} \;
```

## Install website

After the repository has been cloned from Github above, proceed by making your own `.config.sh` file based on the [.config.sh.template](https://github.com/cyclestreets/cyclestreets-setup/blob/master/.config.sh.template) file.

    cd /opt/cyclestreets-setup/
    cp .config.sh.template .config.sh
    pico -w .config.sh

The *root* user is required to install the packages, but most of the installation is done as the *cyclestreets* user (using `sudo`).

    cd /opt/cyclestreets-setup/
    sudo install-website/run.sh


## Use

Once the script has run you should be able to go to:

    http://localhost/

    or

    http://*csHostname*/

to see the CycleStreets home page.

## Install import

    user@machine:/opt/cyclestreets-setup/$ sudo install-import/run.sh

## Run an import

    cyclestreets@machine:/opt/cyclestreets-setup/$ import-deployment/import.sh 


## Troubleshooting

Check apache2 logs in `/websites/www/logs/` or `/var/log/apache2/`.

If you've chosen a *csHostname* other than *localhost* make sure it routes to the server, eg by adding a line to /etc/hosts

### Virtual Box

When the server is built inside a virtual machine, a mapping needs to be maintained from the host.
When using virtual box this can be done with *Port forwarding* either through the VB gui or with this
(where "Ubuntu 16.04.3 LTS" is the name of the Virtual Box virtual machine) :

```
# Run from the host when the virtual machine is turned off
# This maps calls from the host's browser port 3080 to port 80 inside the VM.
# Similar for 3022 and 22 which is for ssh.
# user@host$
VBoxManage modifyvm "Ubuntu 16.04.3 LTS" --natpf1 "http,tcp,,3080,,80"
VBoxManage modifyvm "Ubuntu 16.04.3 LTS" --natpf1 "ssh,tcp,,3022,,22"
```

Within the VM itself the reverse mapping needs to be applied:
```
# user@virtualmachine$
sudo iptables -t nat -I OUTPUT -p tcp -o lo --dport 3080 -j REDIRECT --to-ports 80

# To view nat rules use:
sudo iptables -t nat -L
```

When setup the site can be viewed from the host browser by appending the port :3080 e.g:
`http://thoday.weecee:3080/journey/`

You'll need to do this for the api too in the .config.php:
`http://api-thoday.weecee:3080/v2/journey.planplans=balanced&speed=20&waypoints=0.1417,52.19549%7C0.139,52.19935`
