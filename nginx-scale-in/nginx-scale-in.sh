#!/bin/bash
  
MONGO_DB_IP=""
MONGO_DB_USERNAME=""
MONGO_DB_PASSWORD=""
NGINX_CONF="/etc/nginx/nginx.conf"
TTL="10"
REGEX="[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"
ORIGIN_NETWORK="172.16.16.0/24"
EDGE_NETWORK="172.16.17.0/24"

check_packages() {
        if [ -z `which mongo` ]; then
                sudo apt-get update -qq && sudo apt-get install -y -qq mongodb-clients &> /dev/null
                logger "mongodb-clients package installed."
        fi
        if [ -z `which netmask` ]; then
                sudo apt-get update -qq && sudo apt-get install -y -qq netmask &> /dev/null
                logger "netmask package installed."
        fi

}

check_amscluster() {
        if [ -z "$MONGO_DB_USERNAME" ] && [ -z "$MONGO_DB_PASSWORD" ]; then
                mongo --eval 'db.clusternode.find()' clusterdb --host $MONGO_DB_IP | grep "_id" | grep -Eo "$REGEX" | sort | uniq
        fi

        if [ ! -z "$MONGO_DB_USERNAME" ] && [ ! -z "$MONGO_DB_PASSWORD" ]; then
                mongo --eval 'db.clusternode.find()' clusterdb --host $MONGO_DB_IP --username $MONGO_DB_USERNAME --password $MONGO_DB_PASSWORD | grep "_id" | grep -Eo "$REGEX"| sort | uniq
        fi
}

check_packages

while VAR=$(check_amscluster) 
do
        for i in $VAR; do
                check=$(grep -o $i $NGINX_CONF|wc -l)
                if [[ $i =~ ^(([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))\.){3}([1-9]?[0-9]|1[0-9][0-9]|2([0-4][0-9]|5[0-5]))$ ]]; then
                        check=$(grep -o $i $NGINX_CONF|wc -l)
                        
                        #Scale-In
                        if [ "$check" == "0" ]; then
                                if [ `netmask $i/24 -c` == "$ORIGIN_NETWORK" ]; then
                                        logger "Ant Media Cluster Origin IP Added: $i"
                                        sed -i "/upstream antmedia_origin {/a server $i:5080;" $NGINX_CONF
                                        systemctl reload nginx
                                elif [ `netmask $i/24 -c` == "$EDGE_NETWORK" ]; then
                                        logger "Ant Media Cluster Edge IP Added: $i"
                                        sed -i "/upstream antmedia_edge {/a server $i:5080;" $NGINX_CONF
                                        systemctl reload nginx
                                fi                      
                        fi

                        #Scale-Out
                        SCALE_OUT=$(diff <(cat $NGINX_CONF| grep -Eo "$REGEX" | sort | uniq) <(check_amscluster) --changed-group-format='%<' --unchanged-group-format='')
                        for out in $SCALE_OUT; do 
                                if [ "$SCALE_OUT|wc -l" != "0" ]; then
                                        sed -i "/$out:5080;/d" $NGINX_CONF
                                        logger "Ant Media Cluster IP Deleted: $out"
                                fi
                        done
                fi
        done

        sleep $TTL
done
