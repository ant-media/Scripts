#!/bin/bash
sudo sed -i 's/#\\$nrconf{kernelhints} = -1;/\\$nrconf{kernelhints} = -1;/g'  /etc/needrestart/needrestart.conf
echo 'NEEDRESTART_SUSPEND=1' >> /etc/environment
sudo source /etc/environment
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get purge droplet-agent -y
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 443/tcp
sudo ufw allow 80/tcp
sudo ufw allow 5080/tcp
sudo ufw allow 1935/tcp
sudo ufw allow 5443/tcp
sudo ufw allow 50000:65000/udp
sudo ufw allow 4200/udp
echo "y" | sudo ufw enable
sudo systemctl stop antmedia
sudo sed -i 's/server.marketplace=.*/server.marketplace=do/g' /usr/local/antmedia/conf/red5.properties
sudo dpkg -P droplet-agent
sudo rm -rf /root/.ssh
sudo rm -rf /usr/local/antmedia/conf/instanceId
sudo rm -rf /usr/local/antmedia/*.db.*
sudo rm -rf /usr/local/antmedia/*.db
sudo rm -rf /root/*.zip && rm -rf /root/install*

wget https://raw.githubusercontent.com/digitalocean/marketplace-partners/master/scripts/90-cleanup.sh
wget https://raw.githubusercontent.com/digitalocean/marketplace-partners/master/scripts/99-img-check.sh

bash 90-cleanup.sh
bash 99-img-check.sh
history -c
