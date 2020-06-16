#!/bin/bash

#
# Download latest ant media server and run this script by giving the zip file
# ./install_ant-media-server.sh ant-media-server-*.zip
# If you want to save setting from previous installation add argument true
# ./install_ant-media-server.sh ant-media-server-*.zip true

AMS_BASE=/usr/local/antmedia
BACKUP_DIR="/usr/local/antmedia-backup-"$(date +"%Y-%m-%d_%H-%M-%S")
SAVE_SETTINGS=false


restore_settings() {
  webapps=("LiveApp" "WebRTC*" "root") 

  for i in ${webapps[*]}; do
        while [ ! -d $AMS_BASE/webapps/$i/WEB-INF/ ]; do
                sleep 1
        done
        if [ -d $BACKUP_DIR/webapps/$i/ ]; then
          cp -p -r $BACKUP_DIR/webapps/$i/WEB-INF/red5-web.properties $AMS_BASE/webapps/$i/WEB-INF/red5-web.properties
          if [ -d $BACKUP_DIR/webapps/$i/streams/ ]; then
            cp -p -r $BACKUP_DIR/webapps/$i/streams/ $AMS_BASE/webapps/$i/
          fi
        fi
  done

  diff_webapps=$(diff <(ls $AMS_BASE/webapps/) <(ls $BACKUP_DIR/webapps/) | awk -F">" '{print $2}' | xargs)

  if [ ! -z "$diff_webapps" ]; then
    for custom_app in $diff_webapps; do
      mkdir $AMS_BASE/webapps/$custom_app
      unzip $AMS_BASE/StreamApp*.war -d $AMS_BASE/webapps/$custom_app
      sleep 2
      cp -p $BACKUP_DIR/webapps/$custom_app/WEB-INF/red5-web.properties $AMS_BASE/webapps/$custom_app/WEB-INF/red5-web.properties
      if [ -d $BACKUP_DIR/webapps/$custom_app/streams/ ]; then
        cp -p -r $BACKUP_DIR/webapps/$custom_app/streams/ $AMS_BASE/webapps/$custom_app/
      fi
    done
  fi

  find $BACKUP_DIR/ -type f -iname "*.db" -exec cp -p {} $AMS_BASE/ \;

  #SSL Restore
  if [ $(grep -o -E '<!-- https start -->|<!-- https end -->' $BACKUP_DIR/conf/jee-container.xml  | wc -l) == "2" ]; then
    ssl_files=("red5.properties" "jee-container.xml" "truststore.jks" "keystore.jks")
    for ssl in ${ssl_files[*]}; do
      cp -p $BACKUP_DIR/conf/$ssl $AMS_BASE/conf/
    done
  fi

  if [ $? -eq "0" ]; then
    echo "Settings are restored."
  else
    echo "Settings are not restored. Please send the log of this console to contact@antmedia.io"
  fi
}

distro () {
  os_release="/etc/os-release"
  if [ -f "$os_release" ]; then
    . $os_release
    msg="We are supporting Ubuntu 16.04, 18.04 and Centos 7."
    if [ "$ID" == "ubuntu" ] || [ "$ID" == "centos" ]; then  
      if [ "$VERSION_ID" != "18.04" ] && [ "$VERSION_ID" != "16.04" ] && [ "$VERSION_ID" != "7" ] ; then
         echo $msg
         exit 1
            fi
    else
      echo $msg
      exit 1
    fi
  fi
}

distro

check() {
  OUT=$?
  if [ $OUT -ne 0 ]; then
    echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
    exit $OUT
  fi
}

if [ -z "$1" ]; then
  echo "Please give the Ant Media Server zip file as parameter"
  echo "$0  ant-media-server-....zip"
  exit 1
fi

if [ ! -z "$2" ]; then
   SAVE_SETTINGS=$2
fi

SUDO="sudo"
if ! [ -x "$(command -v sudo)" ]; then
  SUDO=""
fi

if [ "$ID" == "ubuntu" ]; then
  $SUDO apt-get update -y
  check
  $SUDO apt-get install openjdk-8-jdk unzip jsvc -y
  check
  #update-java-alternatives -s java-1.8.0-openjdk-amd64
  openjfxExists=`apt-cache search openjfx | wc -l`
  if [ "$openjfxExists" -gt "0" ];
    then
      $SUDO apt install openjfx=8u161-b12-1ubuntu2 libopenjfx-java=8u161-b12-1ubuntu2 libopenjfx-jni=8u161-b12-1ubuntu2 -y 
      $SUDO apt-mark hold openjfx libopenjfx-java libopenjfx-jni
  fi          
elif [ "$ID" == "centos" ]; then
  $SUDO yum -y install java-1.8.0-openjdk unzip apache-commons-daemon-jsvc 
  check
  if [ ! -L /usr/lib/jvm/java-8-openjdk-amd64 ]; then
    ln -s /usr/lib/jvm/java-1.8.* /usr/lib/jvm/java-8-openjdk-amd64
  fi
  ports=("5080" "443" "80" "5443" "1935")

  for i in ${ports[*]}
  do
    firewall-cmd --add-port=$i/tcp --permanent > /dev/null 2>&1
  done
  firewall-cmd --add-port=5000-65000/udp --permanent > /dev/null 2>&1
  firewall-cmd --reload > /dev/null 2>&1
fi

unzip $1
check

if ! [ -d $AMS_BASE ]; then
  $SUDO mv ant-media-server $AMS_BASE
  check
else
  $SUDO mv $AMS_BASE $BACKUP_DIR
  check
  $SUDO mv ant-media-server $AMS_BASE
  check
fi

$SUDO sed -i '/JAVA_HOME="\/usr\/lib\/jvm\/java-8-oracle"/c\JAVA_HOME="\/usr\/lib\/jvm\/java-8-openjdk-amd64"'  $AMS_BASE/antmedia
check

$SUDO cp $AMS_BASE/antmedia.service /lib/systemd/system/
check

#converting octal to decimal for centos 
if [ "$ID" == "centos" ]; then
  sed -i 's/-umask 133/-umask 91/g' /lib/systemd/system/antmedia.service
fi

if ! [ -x "$(command -v systemctl)" ]; then
  $SUDO cp $AMS_BASE/antmedia /etc/init.d
  $SUDO update-rc.d antmedia defaults
  $SUDO update-rc.d antmedia enable
  check
else
 
  #total memory in mb
  TOTAL_MEMORY=`vmstat -s -Sm | grep 'total memory' | awk -F' ' '{print $1}'`
  declare -i QUARTER_MEMORY=$TOTAL_MEMORY/4
  declare -i HALF_MEMORY=$TOTAL_MEMORY/2
  declare -i MAX_MEMORY=$TOTAL_MEMORY*85/100
  
  #-Xmx #1/4 of the total memory
  #-Dorg.bytedeco.javacpp.maxbytes=  #1/2 of the total memory
  #-Dorg.bytedeco.javacpp.maxphysicalbytes=    #3/4 of the total memory
  
  MEMORY_LINE="Environment=JVM_MEMORY_OPTIONS="
  MEMORY_LINE_WITH_OPTIONS="$MEMORY_LINE -Xmx${QUARTER_MEMORY}m -Dorg.bytedeco.javacpp.maxbytes=${HALF_MEMORY}m -Dorg.bytedeco.javacpp.maxphysicalbytes=${MAX_MEMORY}m"
  sed 's/${MEMORY_LINE}/${MEMORY_LINE_WITH_OPTIONS}/g' $AMS_BASE/antmedia.service
  
  $SUDO cp $AMS_BASE/antmedia.service /lib/systemd/system/
  $SUDO systemctl daemon-reload
  $SUDO systemctl enable antmedia
  check
fi

$SUDO mkdir $AMS_BASE/log
check

if ! [ $(getent passwd | grep antmedia.*$AMS_BASE) ] ; then
  $SUDO useradd -d $AMS_BASE/ -s /bin/false -r antmedia
  check
fi

$SUDO chown -R antmedia:antmedia $AMS_BASE/
check

$SUDO service antmedia stop &
wait $!
$SUDO service antmedia start
check

if [ $? -eq 0 ]; then
  if [ $SAVE_SETTINGS == "true" ]; then
    sleep 5
    restore_settings
    check
    $SUDO chown -R antmedia:antmedia $AMS_BASE/
    check
    $SUDO service antmedia restart
    check
  fi
  echo "Ant Media Server is started"
else
  echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
fi
