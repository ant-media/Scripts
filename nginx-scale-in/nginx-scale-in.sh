#!/bin/bash
  
MONGO_DB_IP="192.168.1.241"
MONGO_DB_USERNAME=""
MONGO_DB_PASSWORD=""
NGINX_CONF="/etc/nginx/nginx.conf"
TTL="10"

check_mongo() {
        if [ -z `which mongo` ]; then
                sudo apt-get update -qq && sudo apt-get install -y -qq mongodb-clients &> /dev/null
                logger "mongodb-clients package installed."
        fi
}

check_amscluster() {
        if [ -z "$MONGO_DB_USERNAME" ] && [ -z "$MONGO_DB_PASSWORD" ]; then
                mongo --eval 'db.clusternode.find()' clusterdb --host $MONGO_DB_IP | grep "_id" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'| sort | uniq
        fi

        if [ ! -z "$MONGO_DB_USERNAME" ] && [ ! -z "$MONGO_DB_PASSWORD" ]; then
                mongo --eval 'db.clusternode.find()' clusterdb --host $MONGO_DB_IP --username $MONGO_DB_USERNAME --password $MONGO_DB_PASSWORD | grep "_id" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}'| sort | uniq
        fi
}

check_mongo

VAR=$(check_amscluster)

while true
do
        for i in $VAR; do
                check=$(grep -o $i $NGINX_CONF|wc -l)
                if [ "$check" == "0" ]; then
                        logger "Ant Media Cluster IP Added: $i"
                        sed -i "/upstream antmedia_edge {/a server $i:5080;" $NGINX_CONF
                        systemctl reload nginx
                fi
        done
        sleep $TTL
done
