
 
When a node joins the Cluster in Ant Media Server, this script automatically adds it to the Nginx Load Balancer.

# Installation

1. Copy the nginx-scale-in.sh file to /usr/bin/ and give it run executable permission.

wget -O /usr/bin/nginx-scale-in.sh https://raw.githubusercontent.com/ant-media/Scripts/nginx-scale-in/nginx-scale-in.sh
chmod +x /usr/bin/nginx-scale-in.sh

2. Copy the antmedia-cluster-check.service file to /etc/systemd/system/ 

wget -O /etc/systemd/system/antmedia-cluster-check.service https://raw.githubusercontent.com/ant-media/Scripts/nginx-scale-in/antmedia-cluster-check.service

3. Run the commands below in order.

systemctl daemon-reload
systemctl enable antmedia-cluster-check.service
systemctl start antmedia-cluster-check.service

4. You can check /var/log/syslog file for debug.

tail -f /var/log/syslog
