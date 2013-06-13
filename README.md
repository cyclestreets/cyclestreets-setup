cyclestreets-setup
==================

Scripts for installing CycleStreets, developing for Ubuntu 12.10 / Debian Squeeze

**Note this is work-in-progress and the CycleStreets repo which is needed is not yet publicly available.**

A suggested place to clone this repository is into your `~/src` folder:

    cyclestreets@machine:~/src$ git clone https://github.com/cyclestreets/cyclestreets-setup.git

After the repository has been cloned from github, proceed by making your own *.config.sh* file based on the *.config.sh.template* file.

The *root* user is required to install the packages, but most of the installation is done as the *cyclestreets* user (using *sudo*).

Use
===

Once the script has run you should be able to go to:

http://localhost/

to see the CycleStreets home page.

Troubleshooting
===============
Check apache2 logs in `/websites/www/logs/` or `/var/logs/apache2/`.