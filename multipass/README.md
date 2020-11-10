# Multipass

Create a CycleStreets website running in an ubuntu virtual server on your host machine.

Download the [Multipass](https://multipass.run/) app for your OS to set up a mini-cloud on a laptop or desktop PC.

Update the cyclestreets-setup repo and proceed as follows:

```shell
# Git config
# Your local git configuration should be setup with your git login name, email and personal access token.
# The installation will copy your ~/.gitconfig to the virtual machine so that it
# can fetch the repositories using your git identity without passwords.
# If you haven't already, provide the following:
# git config --global user.name "${git_user_name}"
# git config --global user.email "${git_user_email}"
#
# https://github.com/settings/tokens/
# git config --global url."https://api:${git_personal_access_token}@github.com/".insteadOf "https://github.com/"


# Start in the setup folder on the host machine (i.e. your laptop/desktop pc):
cd /opt/cyclestreets-setup/multipass/

# Either
# Provide the credentials based on the template:
# cp .config.sh.template .config.sh
# Or
# Alternatively symlink to a prepared version:
# ln -s <your configuration directory>.config.sh /opt/cyclestreets-setup/multipass/.config.sh

# Instantiate the virtual machine and setup the website
./run.sh
```
