#!/bin/bash
#
# This script creates user for standalone aws server and cloudformation template.
#
INITIALIZED=/usr/local/antmedia/conf/initialized
if [ ! -f "$INITIALIZED" ]
then
  ## Local IPV4

  export LOCAL_IPv4=`curl -s http://169.254.169.254/latest/meta-data/local-ipv4`

  # $HOSTNAME ip-172-30-0-216
  HOST_NAME=`hostname`

  HOST_LINE="$LOCAL_IPv4 $HOST_NAME"
  grep -Fxq "$HOST_LINE" /etc/hosts
  
  OUT=$?
  if [ $OUT -ne 0 ]; then   

    echo  "$HOST_LINE" | tee -a /etc/hosts
    OUT=$?

    if [ $OUT -ne 0 ]; then
      echo "Cannot write hosts file"
      exit $OUT
    fi
  fi 
  ## Instance ID
  export INSTANCE_ID=`curl -s http://169.254.169.254/latest/meta-data/instance-id`

  ## Add Initial User with curl
  RESULT=`curl -s -X POST -H "Content-Type: application/json" -d '{"email": "JamesBond", "password": "'$INSTANCE_ID'", "scope": "system", "userType": "ADMIN"}' http://localhost:5080/rest/v2/users/initial`

  echo ${RESULT} | grep --quiet ":true"  

  if [ ! $1 ]; then
    echo ${RESULT} | grep --quiet ":true"
    if [ $? = 1 ]; then
      echo "Cannot create initial user"
      echo "sleep 3 ; /usr/local/antmedia/conf/init.sh"  | at now
      exit $OUT
    else
      echo ${RESULT} | grep --quiet ":true"
    fi

  fi
  touch $INITIALIZED
  ## Add default ServerSecretKey
  SECRET_KEY=$(openssl rand -base64 32 | head -c 32)
  sudo sed -i "/^server.jwtServerControlEnabled=/s|.*|server.jwtServerControlEnabled=true|" /usr/local/antmedia/conf/red5.properties
  sudo sed -i "/^server.jwtServerSecretKey=/s|.*|server.jwtServerSecretKey=$SECRET_KEY|" /usr/local/antmedia/conf/red5.properties
fi
