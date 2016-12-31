# cyclestreets-setup

Scripts for installing CycleStreets, written for Ubuntu Server 16.04 LTS

**Note this is work-in-progress and the CycleStreets repo which is needed is not yet publicly available.**

## Requirements

Written for Ubuntu Server 16.04 LTS.
Earlier versions of scripts tested, March 2015 on a Ubuntu Server 14.04.2 LTS VM with 1 GB RAM, 8GB HD.


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

# Your existing shell cannot obtain the privileges of this new group;
# you may replace it with:
exec newgrp rollout

# Login
# user@other-machine:~$
ssh user@machine

# Set ownership and group
# user@machine:~$
sudo chown -R cyclestreets.rollout /opt/cyclestreets-setup

# Set group permissions and add sticky group bit
sudo chmod -R g+w /opt/cyclestreets-setup
sudo find /opt/cyclestreets-setup -type d -exec chmod g+s {} \;
```

## Install website

After the repository has been cloned from Github above, proceed by making your own `.config.sh` file based on the [.config.sh.template](https://github.com/cyclestreets/cyclestreets-setup/blob/master/.config.sh.template) file.

Provide a password for the subversion repository for your username, ie `repopassword` in the config file. By default the script will try the same password as provided for the cyclestreteets user.

The *root* user is required to install the packages, but most of the installation is done as the *cyclestreets* user (using `sudo`).

    user@machine:/opt/cyclestreets-setup/$ sudo install-website/run.sh


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
