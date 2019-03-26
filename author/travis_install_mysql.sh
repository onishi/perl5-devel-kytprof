#!/bin/bash
set -ex
sudo service mysql stop
sudo apt-get install python-software-properties
cat <<EOC | sudo debconf-set-selections
mysql-apt-config mysql-apt-config/select-server select  mysql-5.7
mysql-apt-config mysql-apt-config/repo-distro   select  ubuntu
EOC
wget https://dev.mysql.com/get/mysql-apt-config_0.8.10-1_all.deb
sudo dpkg --install mysql-apt-config_0.8.10-1_all.deb
sudo apt-get update -q
sudo apt-get install -q -y --allow-unauthenticated -o Dpkg::Options::=--force-confnew mysql-server
sudo mysql_upgrade
