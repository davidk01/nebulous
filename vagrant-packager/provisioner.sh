#!/bin/bash
package_version="0.3"
version="2.2.2"
dir="ruby-${version}"
if [[ ! -e ${dir} ]]; then
  wget http://cache.ruby-lang.org/pub/ruby/2.2/${dir}.tar.gz
  tar xf ${dir}.tar.gz
fi
echo "Cleaning up."
sudo rm -rf opt
rm *.deb
mkdir opt

# install build tools
yum groupinstall -y "Development Tools" "Development Libraries"
# install development libraries
yum install -y openssl-devel libyaml-devel libffi-devel readline-devel zlib-devel gdbm-devel ncurses-devel

# configure, make, install
pushd ruby-${version}
./configure --prefix=/opt/ruby-${version} --enable-load-relative --disable-install-capi --disable-debug --disable-dependency-tracking --disable-install-doc --enable-shared
make -j
make install
popd

# install bundler and fpm because we are going to use them
# adds some fat to the package but not too big a deal
export PATH=/opt/ruby-${version}/bin:$PATH
gem install bundler fpm --no-ri --no-rdoc

# clone the repo and bundle the gems
repo="https://github.com/davidk01/nebulous.git"
git clone ${repo}
pushd nebulous
bundle package --all
bundle install --without test development --deployment --standalone
popd

# at this point we have a ruby in /opt/ruby-${version} and bundled gems and code in /home/vagrant/nebulous
# so time to package stuff up, as an rpm
rm -rf nebulous/.git nebulous/.gitignore
mv nebulous /opt

# package stuff with fpm
fpm -s dir -t rpm --name 'nebulous' --epoch 1 --maintainer 'davidk01@github' --version ${package_version} /opt/ruby-${version} /opt/nebulous

# Move it to shared directory
cp *.rpm /vagrant
