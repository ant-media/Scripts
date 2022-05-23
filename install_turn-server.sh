#!/bin/bash
#
# Turn Server Installation Script
# 

IP=`curl http://checkip.amazonaws.com`
USERNAME=$(openssl rand -hex 6)
PASSWORD=$(openssl rand -hex 12)

check() {
  OUT=$?
  if [ $OUT -ne 0 ]; then
    echo "There is a problem in installing the turn server. Please send the log of this console to support@antmedia.io"
    exit $OUT
  fi
}

sudo apt-get update && apt-get install coturn -y
check
echo "TURNSERVER_ENABLED=1" > /etc/default/coturn
echo "realm=$IP" >> /etc/turnserver.conf
echo "user=$USERNAME:$PASSWORD" >> /etc/turnserver.conf
sudo systemctl enable coturn && sudo systemctl restart coturn
check
echo ""
echo "Username: $USERNAME"
echo "Password: $PASSWORD"
echo "Turn Server Address: $IP"
echo "Please check this guide to enable the Turn Server: https://resources.antmedia.io/docs/turn-server-installation#how-to-add-turn-server-to-ant-media-sample-pages"
echo ""


