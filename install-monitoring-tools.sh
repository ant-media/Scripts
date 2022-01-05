#!/bin/bash

#
# Usage
# sudo ./install-monitoring-tools.sh [-y] [-m MEMORY]
# -y provides headless installation and accepts that server is not behind NAT
# -m MEMORY specifies the memory of the ElasticSearch because ElasticSearch may not be started with default value.
#    You can give -m 2g , -m 2048m as memory limit
#

PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
RED='\033[0;31m'
NC='\033[0m'

HEADLESS_INSTALL=false
ELASTIC_SEARCH_MEMORY=

check() {
  OUT=$?
  if [ $OUT -ne 0 ]; then
    echo "There is a problem in installing the monitoring tools. Please take a look at the logs above to understand the problem. If you need help, please send the log of this console to support@antmedia.io"
    exit $OUT
  fi
}

distro () {
  os_release="/etc/os-release"
  if [ -f "$os_release" ]; then
    . $os_release
    msg="We are supporting Ubuntu 18.04, Ubuntu 20.04, Ubuntu 20.10"

  elif [ "$ID" == "ubuntu" ] || [ "$ID" == "centos" ]; then
      if [ "$VERSION_ID" != "18.04" ] && [ "$VERSION_ID" != "20.04" ] && [ "$VERSION_ID" != "20.10" ]; then
         echo $msg
         exit 1
      fi
  else
      echo $msg
      exit 1
  fi
}

check_network () {

  if [ "$HEADLESS_INSTALL" == "false" ]; then
      echo -e "Are you using the monitoring tool behind the NAT network? [Y/n]"
      read nat
      nat=${nat^}
      if [ "$nat" == "Y" ]; then
         read -p "Please enter your private IP: " private_ip
         PRIVATE_IP=$private_ip
         if [ -z $PRIVATE_IP ]; then
            echo "Private IP cannot be empty."
            exit 1
         fi
      else
         PRIVATE_IP="127.0.0.1"
      fi
  else
    #default value is not installing behind NAT
    PRIVATE_IP="127.0.0.1"
  fi
}

check_ip() {
  if [[ $PRIVATE_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
     echo ""
  else
     echo -e "\e[41mPlease enter valid IP address.${NC}"
     check_network
  fi
}

# y means headless installation
while getopts 'ym:' option
do
  case "${option}" in
    y) HEADLESS_INSTALL=true  ;;
    m) ELASTIC_SEARCH_MEMORY=${OPTARG} ;;
  esac
done

distro
check_network
check_ip

install () {
    sudo apt-get update -qq 2> /dev/null
    check
    sudo apt-get install apt-transport-https software-properties-common wget -y -qq
    check
    sudo rm -rf /opt/kafka*
    check
    wget -qO- https://raw.githubusercontent.com/ant-media/Scripts/master/cloudformation/kafka_2.13-2.8.1.tgz | tar -zxvf -  -C /opt/ && mv /opt/kafka* /opt/kafka
    check
    wget -qO- https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
    check
    
    echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list
    check
    wget -qO- https://packages.grafana.com/gpg.key | sudo apt-key add -
    check
    sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
    check
    sudo apt-get update -qq 2> /dev/null 
    check
    sudo apt-get install openjdk-8-jdk -y -qq
    check
    sudo apt-get install elasticsearch logstash grafana -y -qq
    check

    CPU=$(grep -c 'processor' /proc/cpuinfo)
    check
    
    MEMORY=$(awk '/MemTotal/ {print int($2/1024/1024)}' /proc/meminfo)
    check

    DASHBOARD_URL="https://raw.githubusercontent.com/ant-media/Scripts/master/monitor/antmediaserver.json"
    DATASOURCE_URL="https://raw.githubusercontent.com/ant-media/Scripts/master/monitor/datasource.json"

    if [ "$MEMORY" -ge "7" ]; then
        sudo sed -i -e 's/-Xms1g/-Xms4g/g' -e 's/-Xmx1g/-Xmx4g/g' /etc/logstash/jvm.options
    fi

    sudo sed -i "s/#.*pipeline.workers: 2/pipeline.workers: $CPU/g" /etc/logstash/logstash.yml
    check
    
    sudo sed -i 's/num.partitions=1/num.partitions=4/g' /opt/kafka/config/server.properties
    check

    sudo cat <<EOF > /lib/systemd/system/kafka.service

        [Unit]
        Description=Apache Kafka Server
        Requires=network.target remote-fs.target
        After=network.target remote-fs.target kafka-zookeeper.service

        [Service]
        Type=simple
        Environment=JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64
        ExecStart=/opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
        ExecStop=/opt/kafka/bin/kafka-server-stop.sh

        [Install]
        WantedBy=multi-user.target

EOF

    sudo cat << EOF > /lib/systemd/system/kafka-zookeeper.service

        [Unit]
        Description=Apache Zookeeper Server
        Requires=network.target remote-fs.target
        After=network.target remote-fs.target

        [Service]
        Type=simple
        Environment=JAVA_HOME=/usr/lib/jvm/java-1.8.0-openjdk-amd64
        ExecStart=/opt/kafka/bin/zookeeper-server-start.sh /opt/kafka/config/zookeeper.properties
        ExecStop=/opt/kafka/bin/zookeeper-server-stop.sh

        [Install]
        WantedBy=multi-user.target
EOF

        sudo cat <<EOF > /etc/logstash/conf.d/logstash.conf
        input {
          kafka {
        bootstrap_servers => "127.0.0.1:9092"
        client_id => "logstash"
        group_id => "logstash"
        consumer_threads => 4
        topics => ["ams-instance-stats","ams-webrtc-stats","kafka-webrtc-tester-stats"]
        codec => "json"
        tags => ["log", "kafka_source"]
        type => "log"
          }
        }

        output {
          elasticsearch {
         hosts => ["127.0.0.1:9200"]
         index => "logstash-%{[type]}-%{+YYYY.MM.dd}"
          }
        }
EOF

    sudo cat <<EOF >> /opt/kafka/config/server.properties
        advertised.listeners=INTERNAL_PLAINTEXT://$PRIVATE_IP:9093,EXTERNAL_PLAINTEXT://$PUBLIC_IP:9092
        listeners=INTERNAL_PLAINTEXT://0.0.0.0:9093,EXTERNAL_PLAINTEXT://0.0.0.0:9092
        inter.broker.listener.name=INTERNAL_PLAINTEXT
        listener.security.protocol.map=INTERNAL_PLAINTEXT:PLAINTEXT,EXTERNAL_PLAINTEXT:PLAINTEXT
EOF


	sudo systemctl daemon-reload
    check
    
    sudo systemctl enable grafana-server
    check
    
    sudo systemctl restart grafana-server
    check

    wget -q $DASHBOARD_URL -O /tmp/antmediaserver.json
    check
    wget -q $DATASOURCE_URL -O /tmp/antmedia-datasource.json
    check

    sleep 5

    sudo curl -s "http://127.0.0.1:3000/api/dashboards/db" \
        -u "admin:admin" \
        -H "Content-Type: application/json" \
        --data-binary "@/tmp/antmediaserver.json" > /tmp/curl.log

    check
    
    sudo curl -s -X "POST" "http://127.0.0.1:3000/api/datasources" \
        -H "Content-Type: application/json" \
        -u "admin:admin" \
        --data-binary "@/tmp/antmedia-datasource.json" >> /tmp/curl.log
        
    check
    
    if [ ! -z $ELASTIC_SEARCH_MEMORY ]; then
       
        sudo sed -i "/.*-Xmx.*/c\-Xmx${ELASTIC_SEARCH_MEMORY}" /etc/elasticsearch/jvm.options
        sudo sed -i "/.*-Xms.*/c\-Xms${ELASTIC_SEARCH_MEMORY}" /etc/elasticsearch/jvm.options
           
    fi
   
    
    echo "Enabling Logstash"
    sudo systemctl enable logstash.service
    check
    
    echo "Enabling Elasticsearch"
    sudo systemctl enable elasticsearch
    check
    
    echo "Enabling Kafka"
    sudo systemctl enable kafka
    check
    
    echo "Enabling Kafka-zookeeper"
    sudo systemctl enable kafka-zookeeper
    check
    
    echo "Starting kafka-zookeeper"
    sudo systemctl restart kafka-zookeeper
    check
    
    echo "Starting Kafka"
    sudo systemctl restart kafka
    check
    
    echo "Starting Elasticsearch"
    sudo systemctl restart elasticsearch
    OUT=$?
    if [ $OUT -ne 0 ]; then
        echo "Elastic search is not started. The problem may be about memory limit. You can give memory limit with -m option. Such as -m 4g, -m 1g . If that does not help, please send the log of this console to support@antmedia.io"
        exit $OUT
    fi
    
    echo "Starting Logstash"
    sudo systemctl restart logstash
    check
}
echo "Installing Ant Media Server Monitor Tools"

install

echo "Monitor Tools Installed succesfully..."

echo -e "\n"
echo -e "Login URL: ${RED}http://$PUBLIC_IP:3000${NC}"
echo -e "Username and Password: ${RED}admin/admin${NC}\n"

