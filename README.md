cyclestreets-install
====================

Bash script to install CycleStreets on Ubuntu

Developing for Ubuntu 12.10

After the repository has been cloned from github, proceed by making your own *.config.sh* file based on the *.config.sh.template* file.

Running the installation script *run.sh* (as *root*) will:

 * create a *cyclestreets* user
 * download all the necessary packages

The *root* user is required to install the packages, but most of the installation is done as the *cyclestreets* user (using *sudo*).

Note this is work-in-progress and the CycleStreets repo which is needed is not yet publicly available.