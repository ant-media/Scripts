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
          cp -p -r $BACKUP_DIR/webapps/$i/WEB-INF/*.xml $AMS_BASE/webapps/$i/WEB-INF/
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
      cp -p $BACKUP_DIR/webapps/$custom_app/WEB-INF/*.xml $AMS_BASE/webapps/$custom_app/WEB-INF/
      if [ -d $BACKUP_DIR/webapps/$custom_app/streams/ ]; then
  	    cp -p -r $BACKUP_DIR/webapps/$custom_app/streams/ $AMS_BASE/webapps/$custom_app/
      fi
    done
  fi

  find $BACKUP_DIR/ -type f -iname "*.db" -exec cp -p {} $AMS_BASE/ \;
  if [ $? -eq "0" ]; then
    echo "Settings are restored."
  else
    echo "Settings are not restored. Please send the log of this console to contact@antmedia.io"
  fi
}

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

$SUDO apt-get update -y
check $?

$SUDO apt-get install openjdk-8-jdk unzip jsvc -y
check $?

openjfxExists=`apt-cache search openjfx | wc -l`
if [ "$openjfxExists" -gt "0" ];
then
  $SUDO apt-get install openjfx -y
fi

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

if ! [ $(getent passwd | grep antmedia.*$AMS_BASE) ] ; then
  $SUDO useradd -d $AMS_BASE/ -s /bin/false -r antmedia
  check $?
fi

$SUDO chown -R antmedia:antmedia $AMS_BASE/
check $?

$SUDO service antmedia stop &
wait $!
$SUDO service antmedia start
OUT=$?

if [ $OUT -eq 0 ]; then
  if [ $SAVE_SETTINGS == "true" ]; then
    sleep 5
#    $SUDO service antmedia stop
    restore_settings
    check $?
    $SUDO chown -R antmedia:antmedia $AMS_BASE/
    check $?
    $SUDO service antmedia restart
    check $?
  fi
  echo "Ant Media Server is started"
else
  echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
fi

