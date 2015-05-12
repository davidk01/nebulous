# nebulous
OpenNebula stuff for managing Jenkins and Bamboo agent pools

# Development
Just run `vagrant up` and you will get a ruby version for the vagrant user along with all the bundled gems in /home/vagrant.

# Packaging
The packager directory also has a Vagrantfile that will compile ruby from source, put it in /opt, clone this repo, bundle all the gems, move it to /opt, and finally package the whole thing as an RPM.

# Deployment
Make sure you have `~/.one/one_auth` and `~/.one/one_endpoint` containing username/password and XML-RPC endpoint respectively. If you are using secure configuration then make sure you also have the public key for decrypting the secure values. I usually put it in `~/.ssh/config.pub`. The rest of it is just a matter of making sure your configurations and provisioners line up properly. You can keep everything in one repo or two. It doesn't really matter. Just make sure they are accessible somewhere on the file system so that `lib/runner.rb` can read them.

Since there is a lot of ssh shelling out involved the assumption is that the public key of the user running `lib/runner.rb` has their ssh key set up in OpenNebula so that root access with that key is possible. If this is not set up then the VMs will come up but provisioning will fail.

As for the actual code just use `vagrant-packager` to generate an rpm and then install it with `rpm -i`.
