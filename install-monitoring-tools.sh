#!/bin/bash

PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)
RED='\033[0;31m'
NC='\033[0m'

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
  echo -e "Are you using the monitoring tool behind the nat network? [Y/n]"
  read nat
  nat=${nat^}
  if [ "$nat" == "Y" ]; then
     read -p "Please enter your private ip: " private_ip
     PRIVATE_IP=$private_ip
     if [ -z $PRIVATE_IP ]; then
        echo "Private ip cannot be empty."
    exit 1
     fi
  else
     PRIVATE_IP="127.0.0.1"
  fi
}

check_ip() {
  if [[ $PRIVATE_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
     echo ""
  else
     echo -e "\e[41mPlease enter valid ip address.${NC}"
     check_network
  fi
}

distro
check_network
check_ip

install () {
    sudo apt-get update -qq 2> /dev/null
    sudo apt-get install apt-transport-https software-properties-common wget -y -qq
    sudo rm -rf /opt/kafka*
    wget -qO- https://raw.githubusercontent.com/ant-media/Scripts/master/cloudformation/kafka_2.13-2.8.1.tgz | tar -zxvf -  -C /opt/ && mv /opt/kafka* /opt/kafka
    wget -qO- https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add - &> /dev/null
    echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list &> /dev/null
    wget -qO- https://packages.grafana.com/gpg.key | sudo apt-key add - &> /dev/null
    sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main" &> /dev/null
    apt-get update -qq 2> /dev/null && apt-get install elasticsearch logstash grafana openjdk-8-jdk -y -qq &> /dev/null

    CPU=$(grep -c 'processor' /proc/cpuinfo)
    MEMORY=$(awk '/MemTotal/ {print int($2/1024/1024)}' /proc/meminfo)

    DASHBOARD_URL="https://raw.githubusercontent.com/ant-media/Scripts/master/monitor/antmediaserver.json"
    DATASOURCE_URL="https://raw.githubusercontent.com/ant-media/Scripts/master/monitor/datasource.json"

    if [ "$MEMORY" -ge "7" ]; then
        sudo sed -i -e 's/-Xms1g/-Xms4g/g' -e 's/-Xmx1g/-Xmx4g/g' /etc/logstash/jvm.options
    fi

    sudo sed -i "s/#.*pipeline.workers: 2/pipeline.workers: $CPU/g" /etc/logstash/logstash.yml
    sudo sed -i 's/num.partitions=1/num.partitions=4/g' /opt/kafka/config/server.properties

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

    sudo systemctl enable grafana-server -q && sudo systemctl restart grafana-server

    wget -q $DASHBOARD_URL -O /tmp/antmediaserver.json
    wget -q $DATASOURCE_URL -O /tmp/antmedia-datasource.json

    sleep 5

    sudo curl -s "http://127.0.0.1:3000/api/dashboards/db" \
        -u "admin:admin" \
        -H "Content-Type: application/json" \
        --data-binary "@/tmp/antmediaserver.json" > /tmp/curl.log


    sudo curl -s -X "POST" "http://127.0.0.1:3000/api/datasources" \
        -H "Content-Type: application/json" \
        -u "admin:admin" \
        --data-binary "@/tmp/antmedia-datasource.json" >> /tmp/curl.log  
    sudo systemctl daemon-reload
    sudo systemctl enable logstash.service -q && sudo systemctl enable elasticsearch -q && sudo systemctl enable kafka -q && sudo systemctl enable kafka-zookeeper -q
    sudo systemctl restart kafka-zookeeper && sudo systemctl restart kafka && sudo systemctl restart logstash && sudo systemctl restart elasticsearch

}

install &
PID=$!
echo "Installing.."
printf "["
while kill -0 $PID 2> /dev/null; do 
    printf  "."
    sleep 1
done
printf "] \e[41mDone!${NC}"
echo -e "\n"
echo -e "Login URL: ${RED}http://$PUBLIC_IP:3000${NC}"
echo -e "Username and Password: ${RED}admin/admin${NC}\n"
