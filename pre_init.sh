#!/bin/bash
#
# This script creates user for standalone aws server and cloudformation template.
#

INITIALIZED=/usr/local/antmedia/conf/initialized
AMS_INSTALL_LOCATION=/usr/local/antmedia
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
        echo "This instance is auto-managed by Ant Media Auto-Managed CDK"

        export PUBLIC_IPv4=`curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4`
    
        export  FQDN="ams-${PUBLIC_IPv4//./-}.antmedia.cloud"
        sudo echo $FQDN > /usr/local/antmedia/fqdn
        pushd $AMS_INSTALL_LOCATION
        sudo ./enable_ssl.sh -d $FQDN -s false > /usr/local/antmedia/enable_ssl.log 
        popd
    else
        echo "This instance is not auto-managed"
      
    fi
    
    
    DB_URL=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/tags/instance/db-url)
    sudo echo $DB_URL >> /usr/local/antmedia/change_server_mode.log
    if [ -n "$DB_URL" ]; then
        echo "DB URL is set to $DB_URL" >> /usr/local/antmedia/change_server_mode.log
        pushd $AMS_INSTALL_LOCATION
        WORKING_DIR=$(pwd)
        source $WORKING_DIR/conf/functions.sh
        change_server_mode cluster "$DB_URL" >> /usr/local/antmedia/change_server_mode.log 
        popd
    else
        echo "DB URL is not set, using default" >> /usr/local/antmedia/change_server_mode.log
    fi
    
   
fi