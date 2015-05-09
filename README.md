# nebulous
OpenNebula stuff for managing Jenkins and Bamboo agent pools

# Development
Just run `vagrant up` and you will get a ruby version for the vagrant user along with all the bundled gems in /home/vagrant.

# Packaging
The packager directory also has a Vagrantfile that will compile ruby from source, put it in /opt, clone this repo, bundle all the gems, move it to /opt, and finally package the whole thing as an RPM.
