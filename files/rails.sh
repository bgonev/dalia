#!/bin/bash
sudo yum -y install curl
sudo yum -y install postgresql-devel
sudo curl -sSL https://rvm.io/mpapis.asc | gpg --import -
sudo curl -sSL https://get.rvm.io | bash -s stable --ruby
source /home/centos/.rvm/scripts/rvm
sudo curl -sL https://rpm.nodesource.com/setup_6.x | sudo -E bash -
sudo yum -y install nodejs
rvm install "ruby-2.2.2"
gem update --system
echo "gem: --no-document" >> ~/.gemrc
gem install rails -v 5.0.0
sudo wget -q https://toolbelt.heroku.com/install.sh
sudo chmod 755 install.sh
sudo ./install.sh
./install.sh
sudo yum -y install git
rvm install "ruby-2.2.1"
gem install bundler
gem install pg 

