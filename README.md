# cyclestreets-setup

Scripts for installing CycleStreets, developing for Ubuntu 14.04.2 LTS

**Note this is work-in-progress and the CycleStreets repo which is needed is not yet publicly available.**

After the repository has been cloned from Github (see instructions below), proceed by making your own *.config.sh* file based on the *.config.sh.template* file.

The *root* user is required to install the packages, but most of the installation is done as the *cyclestreets* user (using *sudo*).

    cyclestreets@machine:/opt/cyclestreets-setup/install-website$ sudo ./run.sh

## Requirements

In March 2015 it can run on a VM with 2GB RAM, 8GB Disk, based on a Ubuntu 14.04.2 LTS Desktop VM.

## Use

Once the script has run you should be able to go to:

http://localhost/

to see the CycleStreets home page.

## Troubleshooting

Check apache2 logs in `/websites/www/logs/` or `/var/log/apache2/`.


## Setup

Add this repository to a machine using the following, as your normal username (not root). In the listing the grouped items can usually be cut and pasted together into the command shell, others require responding to a prompt:

    cd ~
    sudo apt-get -y install git

    git clone https://github.com/cyclestreets/cyclestreets-setup.git

    sudo mv cyclestreets-setup /opt
    cd /opt/cyclestreets-setup/
    git config core.sharedRepository group

    sudo adduser --gecos "" cyclestreets

    sudo addgroup rollout

    # Some command shells won't detect the preceding group change, so reset your shell eg. by logging out and then back in again
    sudo chown -R cyclestreets.rollout /opt/cyclestreets-setup

    sudo chmod -R g+w /opt/cyclestreets-setup
    sudo find /opt/cyclestreets-setup -type d -exec chmod g+s {} \;
