MODE=$1

if [ $MODE = "cluster" ]
  then
    echo "Mode: cluster"
    DB_TYPE=mongodb
    MONGO_SERVER_IP=$2
    mv /usr/local/antmedia/conf/jee-container.xml /usr/local/antmedia/conf/jee-container-standalone.xml
    mv /usr/local/antmedia/conf/jee-container-cluster.xml /usr/local/antmedia/conf/jee-container.xml
  else
    echo "Mode: standalone"
    DB_TYPE=mapdb
    MONGO_SERVER_IP=localhost
    mv /usr/local/antmedia/conf/jee-container.xml /usr/local/antmedia/conf/jee-container-cluster.xml
    mv /usr/local/antmedia/conf/jee-container-standalone.xml /usr/local/antmedia/conf/jee-container.xml
fi

LIVEAPP_PROPERTIES_FILE=/usr/local/antmedia/webapps/LiveApp/WEB-INF/red5-web.properties
WEBRTCAPP_PROPERTIES_FILE=/usr/local/antmedia/webapps/WebRTCAppEE/WEB-INF/red5-web.properties
CONSOLEAPP_PROPERTIES_FILE=/usr/local/antmedia/webapps/ConsoleApp/WEB-INF/red5-web.properties

sed -i 's/db.type=.*/db.type='$DB_TYPE'/' $LIVEAPP_PROPERTIES_FILE
sed -i 's/db.host=.*/db.host='$MONGO_SERVER_IP'/' $LIVEAPP_PROPERTIES_FILE

sed -i 's/db.type=.*/db.type='$DB_TYPE'/' $WEBRTCAPP_PROPERTIES_FILE
sed -i 's/db.host=.*/db.host='$MONGO_SERVER_IP'/' $WEBRTCAPP_PROPERTIES_FILE

sed -i 's/db.type=.*/db.type='$DB_TYPE'/' $CONSOLEAPP_PROPERTIES_FILE
sed -i 's/db.host=.*/db.host='$MONGO_SERVER_IP'/' $CONSOLEAPP_PROPERTIES_FILE

echo "Ant Media Server will be restarted in $MODE mode."
service antmedia restart
