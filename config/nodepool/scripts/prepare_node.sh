#!/bin/bash -xe

# Copyright (C) 2011-2013 OpenStack Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
# implied.
#
# See the License for the specific language governing permissions and
# limitations under the License.

HOSTNAME=$1
SUDO=$2
THIN=$3
MYSQL_PASS=MYSQL_ROOT_PASSWORD

sudo hostname $HOSTNAME
wget https://git.openstack.org/cgit/openstack-infra/config/plain/install_puppet.sh
sudo bash -xe install_puppet.sh
sudo git clone https://review.openstack.org/p/openstack-infra/config.git \
    /root/config
sudo /bin/bash /root/config/install_modules.sh
#if [ -z "$NODEPOOL_SSH_KEY" ] ; then
sudo puppet apply --modulepath=/root/config/modules:/etc/puppet/modules \
    -e "class {'openstack_project::single_use_slave': sudo => $SUDO, thin => $THIN, }"
#else
#    sudo puppet apply --modulepath=/root/config/modules:/etc/puppet/modules \
#   -e "class {'openstack_project::single_use_slave': install_users => false, sudo => $SUDO, thin => $THIN, ssh_key => '$NODEPOOL_SSH_KEY', }"
#fi

sudo mkdir -p /opt/git
#sudo -i python /opt/nodepool-scripts/cache_git_repos.py

echo "mysql-server mysql-server/root_password select $MYSQL_PASS" | sudo debconf-set-selections
echo "mysql-server mysql-server/root_password_again select $MYSQL_PASS" | sudo debconf-set-selections
sudo apt-get -y install mysql-server libpq-dev libmysqlclient-dev
mysql -uroot -p$MYSQL_PASS -Bse "create database sahara"
mysql -uroot -p$MYSQL_PASS -Bse  "CREATE USER 'sahara-citest'@'localhost' IDENTIFIED BY 'sahara-citest'"
mysql -uroot -p$MYSQL_PASS -Bse "GRANT ALL ON sahara.* TO 'sahara-citest'@'localhost'"
mysql -uroot -p$MYSQL_PASS -Bse "flush privileges"
sudo service mysql stop

#workaround problem 'xslt-config: not found'
sudo apt-get install libxslt1-dev -y

#glance-client is required for diskimage-integration jobs
sudo pip install python-glanceclient
sudo apt-get install qemu kpartx -y

#install Sahara requirements
sudo pip install mysql-python
cd /tmp && git clone https://github.com/openstack/sahara
cd sahara && sudo pip install -U -r requirements.txt

# install requirements for Cloudera plugin
sudo pip install cm-api

# pep8-trunk job requirements
sudo apt-get install gettext -y

# Java tarbal for diskimage jobs
sudo wget --no-check-certificate --no-cookies --header "Cookie: gpw_e24=http%3A%2F%2Fwww.oracle.com%2F; oraclelicense=accept-securebackup-cookie" \
   -P /home/jenkins http://download.oracle.com/otn-pub/java/jdk/7u51-b13/jdk-7u51-linux-x64.tar.gz
sudo chown jenkins:jenkins /home/jenkins/jdk-7u51-linux-x64.tar.gz

pushd /opt
DIB_RELEASE="0.1.17"
wget https://github.com/openstack/diskimage-builder/archive/$DIB_RELEASE.tar.gz
tar xzf $DIB_RELEASE.tar.gz
rm -rf $DIB_RELEASE.tar.gz
popd

sudo su - jenkins -c "echo '
JENKINS_PUBLIC_KEY' >> /home/jenkins/.ssh/authorized_keys"
sync
sleep 20
