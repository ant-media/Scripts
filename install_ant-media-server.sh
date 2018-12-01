#!/bin/bash

#
# Download latest ant media server and run this script by giving the zip file
# ./install_ant-media-server.sh ant-media-server-*.zip
# If you want to save setting from previous installation add argument true
# ./install_ant-media-server.sh ant-media-server-*.zip true

AMS_BASE=/usr/local/antmedia
BACKUP_DIR="/usr/local/antmedia-backup-"$(date +"%Y-%m-%d_%H-%M-%S")
SAVE_SETTINGS=$2

restore_settings() {
  #app settings
  files[0]=/webapps/LiveApp/WEB-INF/red5-web.properties
  files[1]=/webapps/ConsoleApp/WEB-INF/red5-web.properties
  files[2]=/webapps/WebRTCApp/WEB-INF/red5-web.properties
  files[3]=/webapps/WebRTCAppEE/WEB-INF/red5-web.properties
  files[4]=/webapps/root/WEB-INF/red5-web.properties

  #db files
  files[5]=/liveapp.db
  files[6]=/server.db
  files[7]=/webrtcapp.db
  files[8]=/webrtcappee.db

  #copy app settings
  for file in ${files[*]}
  do
    if [ -f $BACKUP_DIR$file ]; then
      $SUDO cp $BACKUP_DIR$file $AMS_BASE$file
    fi
  done

  echo "Settings are restored."
}

check() {
  OUT=$1
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

SUDO="sudo"
if ! [ -x "$(command -v sudo)" ]; then
  SUDO=""
fi

$SUDO apt-get update -y
check $?

$SUDO apt-get install openjdk-8-jdk -y
check $?

$SUDO apt-get install unzip -y
check $?

unzip $1
check $?

if ! [ -d $AMS_BASE ]; then
  $SUDO mv ant-media-server $AMS_BASE
  check $?
else
  $SUDO mv $AMS_BASE $BACKUP_DIR
  check $?
  $SUDO mv ant-media-server $AMS_BASE
  check $?
fi

$SUDO apt-get install jsvc -y
check $?

$SUDO sed -i '/JAVA_HOME="\/usr\/lib\/jvm\/java-8-oracle"/c\JAVA_HOME="\/usr\/lib\/jvm\/java-8-openjdk-amd64"'  $AMS_BASE/antmedia
check $?

$SUDO cp $AMS_BASE/antmedia /etc/init.d/
check $?

$SUDO update-rc.d antmedia defaults
check $?

$SUDO update-rc.d antmedia enable
check $?

$SUDO mkdir $AMS_BASE/log
check $?

if ! [ $(getent passwd | grep antmedia) ] ; then
  $SUDO useradd -d $AMS_BASE/ -s /bin/false -r antmedia
  check $?
fi

$SUDO chown -R antmedia:antmedia $AMS_BASE/
check $?

$SUDO service antmedia stop
$SUDO service antmedia start
OUT=$?

if [ $OUT -eq 0 ]; then
  if [ $SAVE_SETTINGS == "true" ]; then
    sleep 5
    $SUDO service antmedia stop
    restore_settings
    check $?
    $SUDO chown -R antmedia:antmedia $AMS_BASE/
    check $?
    $SUDO service antmedia start
    check $?
  fi
  echo "Ant Media Server is started"
else
  echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
fi
