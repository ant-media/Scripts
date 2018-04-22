#!/bin/bash

# 
# Download latest ant media server and run this script by giving the zip file
# ./install_ant-media-server.sh ant-media-server-*.zip
#

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
OUT=$?
if [ $OUT -ne 0 ]; then
  echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
  exit $OUT
fi

$SUDO apt-get install openjdk-8-jdk -y
OUT=$?
if [ $OUT -ne 0 ]; then
  echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
  exit $OUT
fi

$SUDO apt-get install unzip -y
OUT=$?
if [ $OUT -ne 0 ]; then
  echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
  exit $OUT
fi

unzip $1
OUT=$?
if [ $OUT -ne 0 ]; then
  echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
  exit $OUT
fi

if ! [ -d /usr/local/antmedia ]; then
$SUDO mv ant-media-server /usr/local/antmedia
OUT=$?
  if [ $OUT -ne 0 ]; then
    echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
    exit $OUT
  fi
else
  foldername=$(date +"%Y-%m-%d_%H-%M-%S")
  $SUDO mv /usr/local/antmedia /usr/local/antmedia-backup-"$foldername"
  OUT=$?
    if [ $OUT -ne 0 ]; then
      echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
      exit $OUT
    fi
  $SUDO mv ant-media-server /usr/local/antmedia
  OUT=$?
    if [ $OUT -ne 0 ]; then
      echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
      exit $OUT
    fi
fi

$SUDO apt-get install jsvc -y
OUT=$?
if [ $OUT -ne 0 ]; then
  echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
  exit $OUT
fi

$SUDO sed -i '/JAVA_HOME="\/usr\/lib\/jvm\/java-8-oracle"/c\JAVA_HOME="\/usr\/lib\/jvm\/java-8-openjdk-amd64"'  /usr/local/antmedia/antmedia
OUT=$?
if [ $OUT -ne 0 ]; then
  echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
  exit $OUT
fi

$SUDO cp /usr/local/antmedia/antmedia /etc/init.d/
OUT=$?
if [ $OUT -ne 0 ]; then
  echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
  exit $OUT
fi

$SUDO update-rc.d antmedia defaults
OUT=$?
if [ $OUT -ne 0 ]; then
  echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
  exit $OUT
fi

$SUDO update-rc.d antmedia enable
OUT=$?
if [ $OUT -ne 0 ]; then
  echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
  exit $OUT
fi

$SUDO mkdir /usr/local/antmedia/log
OUT=$?
if [ $OUT -ne 0 ]; then
  echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
  exit $OUT
fi

if ! [ $(getent passwd | grep antmedia) ] ; then
  $SUDO useradd -d /usr/local/antmedia/ -s /bin/false -r antmedia
  OUT=$?
  if [ $OUT -ne 0 ]; then
    echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
    exit $OUT
  fi
fi

$SUDO chown -R antmedia:antmedia /usr/local/antmedia/
OUT=$?
if [ $OUT -ne 0 ]; then
  echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
  exit $OUT
fi

$SUDO service antmedia restart
OUT=$?

if [ $OUT -eq 0 ]; then
echo "Ant Media Server is started"
else
echo "There is a problem in installing the ant media server. Please send the log of this console to contact@antmedia.io"
fi