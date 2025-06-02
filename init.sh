#!/bin/bash
#
# This script creates user for standalone aws server and cloudformation template.
#
INITIALIZED=/usr/local/antmedia/conf/initialized
if [ ! -f "$INITIALIZED" ]
then
  TOKEN=`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
  ## Local IPV4

  export LOCAL_IPv4=`curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4`

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
  export INSTANCE_ID=`curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id`
  
  #check if first login
  
  RESULT=`curl -s -X GET -H "Content-Type: application/json" http://localhost:5080/rest/v2/first-login-status`
  echo ${RESULT} | grep --quiet ":false" 
  
  #if the above commands returns 0, it means server is already initialized
  if [ $? = 0 ]; then
    echo "First login is not true"
    touch $INITIALIZED
    exit 0
  else 
  	TAG_VALUE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/tags/instance/auto-managed-ams)
  	if [ "$TAG_VALUE" = "true" ]; then
  	     #get username and password from tags
  	     USERNAME=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/tags/instance/web-panel-login-email)
  	     #password is the md5 of the instance id
  	     PASSWORD=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/tags/instance/web-panel-login-password)
  	     
  	else
  		USERNAME="JamesBond"
  	    PASSWORD=$(echo -n $INSTANCE_ID | md5sum | awk '{print $1}' )
  	    
    fi
  
  
     ## Add Initial User with curl
    RESULT=`curl -s -X POST -H "Content-Type: application/json" -d '{"email": "'$USERNAME'", "password": "'$PASSWORD'", "scope": "system", "userType": "ADMIN"}' http://localhost:5080/rest/v2/users/initial`

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
  
  fi

fi