#!/bin/bash

set -e

########################################
# 0) Ask the user for the tenant email
########################################
while true; do
    read -rp "Please enter your license email address (this will be used as the tenant): " TENANT_EMAIL
    if [[ -n "$TENANT_EMAIL" ]]; then
        break
    else
        echo "Tenant email cannot be empty!"
    fi
done

echo "Tenant set to: $TENANT_EMAIL"



sudo sh -c 'curl -s https://packages.fluentbit.io/fluentbit.key | gpg --dearmor > /usr/share/keyrings/fluentbit-keyring.gpg'

codename=$(grep -oP '(?<=VERSION_CODENAME=).*' /etc/os-release 2>/dev/null || lsb_release -cs 2>/dev/null)

echo "deb [signed-by=/usr/share/keyrings/fluentbit-keyring.gpg] https://packages.fluentbit.io/ubuntu/$codename $codename main" \
  | sudo tee /etc/apt/sources.list.d/fluent-bit.list

sudo apt-get update -qq
sudo apt-get install fluent-bit -qq -y


HOST_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 || hostname -I | awk '{print $1}')

sudo bash -c "echo HOST_IP=\"$HOST_IP\" > /etc/default/fluent-bit"
sudo bash -c "echo TENANT_EMAIL=\"$TENANT_EMAIL\" >> /etc/default/fluent-bit"


sudo bash -c 'cat > /etc/fluent-bit/fluent-bit.conf << "EOF"
[SERVICE]
    Flush        1
    Log_Level    info
    Parsers_File parsers.conf

[INPUT]
    Name              tail
    Path              /var/log/antmedia/ant-media-server.log
    Tag               ams
    DB                /var/log/antmedia/flb.db
    Read_from_Head    On
    Refresh_Interval  5
    multiline.parser  java

[FILTER]
    Name    modify
    Match   ams
    Add     instance ${HOSTNAME}
    Add     source_ip ${HOST_IP}

[OUTPUT]
    Name              loki
    Match             ams
    Host              log.antmedia.io
    Port              3100
    URI               /loki/api/v1/push
    tls               Off
    labels            job=antmedia,tenant=${TENANT_EMAIL},instance=${HOSTNAME},source_ip=${HOST_IP}
    line_format       json
EOF'


sudo bash -c 'cat >> /etc/fluent-bit/parsers.conf << "EOF"

[MULTILINE_PARSER]
    name          java
    type          regex
    flush_timeout 1000

    rule "start"  "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2},\d+ .*$" "cont"
    rule "cont"   "^\s+at .*" "cont"
    rule "cont"   "^\s*Caused by: .*" "cont"
    rule "cont"   "^\s*\.\.\. \d+ common frames omitted" "cont"
EOF'


sudo systemctl daemon-reload
sudo systemctl enable fluent-bit
sudo systemctl restart fluent-bit

