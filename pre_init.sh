#!/bin/bash
#
# This script creates user for standalone aws server and cloudformation template.
#
INITIALIZED=/usr/local/antmedia/conf/initialized
if [ ! -f "$INITIALIZED" ]
then
  ## Add default ServerSecretKey
  SECRET_KEY=$(openssl rand -base64 32 | head -c 32)
  sudo sed -i "/^server.jwtServerControlEnabled=/s|.*|server.jwtServerControlEnabled=true|" /usr/local/antmedia/conf/red5.properties
  sudo sed -i "/^server.jwtServerSecretKey=/s|.*|server.jwtServerSecretKey=$SECRET_KEY|" /usr/local/antmedia/conf/red5.properties
fi
