#!/bin/bash
#
# This script creates user for standalone aws server and cloudformation template.
#

INITIALIZED=/usr/local/antmedia/conf/initialized
if [ ! -f "$INITIALIZED" ]
then
  	TOKEN=`curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`


	
    export INSTANCE_ID=`curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id`


    SECRET_KEY=$(echo -n $INSTANCE_ID | md5sum | awk '{print $1}' )
    echo $SECRET_KEY > /usr/local/antmedia/SECRET_KEY
    sudo sed -i "/^server.jwtServerControlEnabled=/s|.*|server.jwtServerControlEnabled=true|" /usr/local/antmedia/conf/red5.properties
    sudo sed -i "/^server.jwtServerSecretKey=/s|.*|server.jwtServerSecretKey=$SECRET_KEY|" /usr/local/antmedia/conf/red5.properties
	
	  TAG_VALUE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/tags/instance/auto-managed-ams)
	  # Get the value of the "auto-managed-ams" tag

    if [ "$TAG_VALUE" = "true" ]; then  
        echo "This instance is auto-managed by Ant Media CloudFormation template"

        export PUBLIC_IPv4=`curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4`
    
        export  FQDN="ams-${PUBLIC_IPv4//./-}.antmedia.cloud"
        sudo echo $FQDN > /usr/local/antmedia/fqdn
        cd /usr/local/antmedia
        sudo ./enable_ssl.sh -d $FQDN > /usr/local/antmedia/enable_ssl.log 
    else
        echo "This instance is not auto-managed"
      
    fi
   
fi