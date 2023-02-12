#!/bin/bash

#
# Download latest ant media server and run this script by giving the zip file
# ./install_ant-media-server.sh ant-media-server-*.zip
# If you want to save setting from previous installation add argument true
# ./install_ant-media-server.sh ant-media-server-*.zip true

# -s : install as a service or not
# -r : restore settings
# -i : ant media server zip file

AMS_BASE=/usr/local/antmedia
BACKUP_DIR="/usr/local/antmedia-backup-"$(date +"%Y-%m-%d_%H-%M-%S")
SAVE_SETTINGS=false
INSTALL_SERVICE=true
ANT_MEDIA_SERVER_ZIP_FILE=
OTHER_DISTRO=false
SERVICE_FILE=/etc/systemd/system/antmedia.service
DEFAULT_JAVA="$(readlink -f $(which java) | rev | cut -d "/" -f3- | rev)"
LOG_DIRECTORY="/var/log/antmedia"
TOTAL_DISK_SPACE=$(df / --total -k -m --output=avail | tail -1 | xargs)
ARCH=`uname -m`

update_script () {
  SCRIPT_NAME="$0"
  remote_file="$(curl -sL https://raw.githubusercontent.com/ant-media/Scripts/master/install_ant-media-server.sh | md5sum | cut -d ' ' -f 1)"
  local_file="$(md5sum $0 | cut -d '' -f 1 )"
  if [ "$remote_file" != "$local_file" ]; then
    wget -O $0 -q https://raw.githubusercontent.com/ant-media/Scripts/master/install_ant-media-server.sh
    chmod +x $0
    echo "Updated the installation script. Please rerun the script."
    exit 1
  fi
}


usage() {
  echo ""
  echo "Usage:"
  echo "$0 OPTIONS"
  echo ""
  echo "OPTIONS:"
  echo "  -i -> Provide Ant Media Server Zip file name. Mandatory"
  echo "  -r -> Restore settings flag. It can accept true or false. Optional. Default value is false"
  echo "  -s -> Install Ant Media Server as a service. It can accept true or false. Optional. Default value is true"
  echo "  -d -> Install Ant Media Server on other Linux operating systems. Default value is false"
  echo "  -u -> Update Ant Media Server new installation script. Default value is false"

  echo ""
  echo "Sample usage:"
  echo "$0 -i name-of-the-ant-media-server-zip-file"
  echo "$0 -i name-of-the-ant-media-server-zip-file -r true -s true"
  echo "$0 -i name-of-the-ant-media-server-zip-file -i false"
  echo "$0 -i name-of-the-ant-media-server-zip-file -d true"
  echo "$0 -u"
  echo ""
}

disk_usage(){
  if [ $SAVE_SETTINGS == "true" ]; then
    if [ $(($(du -sm $AMS_BASE | cut -f 1)*2)) -ge $TOTAL_DISK_SPACE ]; then
      echo "Disk space is not enough."
      exit 1
    fi
  fi
}
# Restore settings
restore_settings() {
  webapps=("LiveApp" "WebRTC*" "root")

  for i in ${webapps[*]}; do
        while [ ! -d $AMS_BASE/webapps/$i/WEB-INF/ ]; do
                sleep 1
        done
        if [ -d $BACKUP_DIR/webapps/$i/ ]; then
          cp -p -r $BACKUP_DIR/webapps/$i/WEB-INF/red5-web.properties $AMS_BASE/webapps/$i/WEB-INF/red5-web.properties
          if [ -d $BACKUP_DIR/webapps/$i/streams/ ]; then
            if [ -L $BACKUP_DIR/webapps/$i/streams ]; then
              ii=`echo $BACKUP_DIR/webapps/$i/streams | cut -d "/" -f 6`
              ln -sf $(readlink -f $BACKUP_DIR/webapps/$i/streams) $AMS_BASE/webapps/$ii/streams
            else
              cp -p -r $BACKUP_DIR/webapps/$i/streams/ $AMS_BASE/webapps/$i/
            fi
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
  cp -p $BACKUP_DIR/conf/{red5.properties,jee-container.xml,instanceId} $AMS_BASE/conf

  #SSL Restore
  if [ $(grep -o -E '<!-- https start -->|<!-- https end -->' $BACKUP_DIR/conf/jee-container.xml  | wc -l) == "2" ]; then
    cp -p $BACKUP_DIR/conf/{chain.pem,privkey.pem,fullchain.pem,truststore.jks,keystore.jks} $AMS_BASE/conf/
  fi

  if [ $(grep 'nativeLogLevel=' $AMS_BASE/conf/red5.properties | wc -l) == "0" ]; then
    $SUDO echo "nativeLogLevel=ERROR" >> $AMS_BASE/conf/red5.properties
  fi


  if [ $(grep 'http.ssl_certificate_chain_file=' $AMS_BASE/conf/red5.properties | wc -l) == "0" ]; then
    $SUDO echo "http.ssl_certificate_chain_file=conf/chain.pem" >> $AMS_BASE/conf/red5.properties
  fi

  if [ $(grep 'SSLCertificateChainFile' $AMS_BASE/conf/jee-container.xml | wc -l) == "0" ]; then
    $SUDO sed -i '/<entry key="SSLCertificateFile.*/a <entry key="SSLCertificateChainFile" value="${http.ssl_certificate_chain_file}" />' $AMS_BASE/conf/jee-container.xml
  fi

  # This is a fix in upgrading versions that uses Http11Nio2Protocol
  # I think we can delete the following two lines after 6 months because it will become useless. 
  # Sep 25, 21 - mekya
  if [ $(grep 'Http11AprProtocol' $AMS_BASE/conf/jee-container.xml | wc -l) != "0" ]; then
    $sudo sed -i 's/org.apache.coyote.http11.Http11AprProtocol/org.apache.coyote.http11.Http11Nio2Protocol/g' $AMS_BASE/conf/jee-container.xml
  fi


  if [ $? -eq "0" ]; then
    echo "Settings are restored."
  else
    echo "Settings are not restored. Please send the log of this console to support@antmedia.io"
  fi
}
#Get the linux distribution
distro () {
  os_release="/etc/os-release"
  if [ -f "$os_release" ]; then
    . $os_release
    msg="We are supporting Ubuntu 18.04, Ubuntu 20.04, Ubuntu 22.04, Centos 8, Rocky Linux 8 and AlmaLinux 8"
    if [ "$OTHER_DISTRO" == "true" ]; then
      echo -e """\n- OpenJDK 11 (openjdk-11-jdk)\n- De-archiver (unzip)\n- Commons Daemon (jsvc)\n- Apache Portable Runtime Library (libapr1)\n- SSL Development Files (libssl-dev)\n- Video Acceleration (VA) API (libva-drm2)\n- Video Acceleration (VA) API - X11 runtime (libva-x11-2)\n- Video Decode and Presentation API Library (libvdpau-dev)\n- Crystal HD Video Decoder Library (libcrystalhd-dev)\n"""
      read -p 'Are you sure that the above packages are installed?  Y/N ' CUSTOM_PACKAGES
      CUSTOM_PACKAGES=${CUSTOM_PACKAGES^}
                  if [ "$CUSTOM_PACKAGES" == "N" ]; then
                echo "Interrupted by user"
                exit 1
            fi

      read -p "Enter JVM Path (default: $DEFAULT_JAVA): " CUSTOM_JVM
      if [ -z "$CUSTOM_JVM" ]; then
        $SUDO apt-get update && $SUDO apt-get install coreutils
        CUSTOM_JVM=$DEFAULT_JAVA
      fi
    elif [ "$ID" == "ubuntu" ] || [ "$ID" == "centos" ] || [ "$ID" == "rocky" ] || [ "$ID" == "almalinux" ]; then
      if [ "$VERSION_ID" == "18.04" ] && [ "aarch64" == $ARCH ]; then
        echo -e "ARM architecture is supported on Ubuntu 20.04. For 18.04 installation, use the link below to install.\nhttps://github.com/ant-media/Ant-Media-Server/wiki/Frequently-Asked-Questions#how-can-i-install-the-ant-media-server-on-ubuntu-1804-with-arm64"
        exit 1
      fi

      if [[ $VERSION_ID != 18.04 ]] && [[ $VERSION_ID != 20.04 ]] && [[ $VERSION_ID != 22.04 ]] && [[ $VERSION_ID != 8* ]]; then
         echo $msg
         exit 1
            fi
    else
      echo $msg
      exit 1
    fi
  fi
}

#Just checks if the latest ioperation is successfull
check() {
  OUT=$?
  if [ $OUT -ne 0 ]; then
    echo "There is a problem in installing the ant media server. Please send the log of this console to support@antmedia.io"
    exit $OUT
  fi
}

# Start

while getopts 'i:s:r:d:hu' option
do
  case "${option}" in
    s) INSTALL_SERVICE=${OPTARG};;
    i) ANT_MEDIA_SERVER_ZIP_FILE=${OPTARG};;
    r) SAVE_SETTINGS=${OPTARG};;
    d) OTHER_DISTRO=${OPTARG};;
    u) UPDATE="true";;
    h) usage
       exit 1;;
   esac
done

disk_usage
distro

if [ "$UPDATE" == "true" ]; then
  update_script
fi

if [ -z "$ANT_MEDIA_SERVER_ZIP_FILE" ]; then
  # it means the previous parameters are used.
  echo "Using old syntax to match the parameters. It's deprecated. Learn the new way by typing $0 -h"
  ANT_MEDIA_SERVER_ZIP_FILE=$1

  if [ ! -z "$2" ]; then
    SAVE_SETTINGS=$2
  fi
fi

if [ -z "$ANT_MEDIA_SERVER_ZIP_FILE" ]; then
  echo "Please give the Ant Media Server zip file as parameter"
  usage
  exit 1
fi

SUDO="sudo"
if ! [ -x "$(command -v sudo)" ]; then
  SUDO=""
fi

VERSION=$(unzip -p "$ANT_MEDIA_SERVER_ZIP_FILE" ant-media-server/ant-media-server.jar  | busybox unzip -p - | grep -a "Implementation-Version"|cut -d' ' -f2 | tr -d '\r')
REQUIRED_VERSION="2.6"

if [ "$ID" == "ubuntu" ]; then
  $SUDO apt-get update -y
  $SUDO apt-get install unzip zip libva-drm2 libva-x11-2 libvdpau-dev -y
  if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
      $SUDO apt-get install libcrystalhd-dev -y
      check
  fi
elif [ "$ID" == "centos" ] || [ "$ID" == "rocky" ] || [ "$ID" == "almalinux" ]; then
  $SUDO yum -y install epel-release
  $SUDO yum -y install unzip zip libva libvdpau
  if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    $SUDO yum -y install libcrystalhd
    check
  fi
  
  if [ ! -L /usr/lib/jvm/java-11-openjdk-amd64 ]; then
    find /usr/lib/jvm/ -maxdepth 1 -type d -iname "java-11*" | head -1 | xargs -i ln -s {} /usr/lib/jvm/java-11-openjdk-amd64
    check
  fi

  ports=("5080" "443" "80" "5443" "1935")

  for i in ${ports[*]}
  do
    firewall-cmd --add-port=$i/tcp --permanent > /dev/null 2>&1
  done
  firewall-cmd --add-port=5000-65000/udp --permanent > /dev/null 2>&1
  firewall-cmd --reload > /dev/null 2>&1
fi

unzip $ANT_MEDIA_SERVER_ZIP_FILE
check

if [[ $VERSION == 2.4* || $VERSION == 2.3* || $VERSION == 2.2* ]]; then
  if [ "$ID" == "ubuntu" ]; then
    $SUDO apt-get update -y
    $SUDO apt-get install openjdk-11-jdk -y
    check
  fi
elif [[ $VERSION == 2.1* || $VERSION == 2.0* || $VERSION == 1.* ]]; then
  if [ "$ID" == "ubuntu" ]; then
    $SUDO apt-get install openjdk-8-jre -y
    $SUDO apt purge openjfx libopenjfx-java libopenjfx-jni -y
    $SUDO apt install openjfx=8u161-b12-1ubuntu2 libopenjfx-java=8u161-b12-1ubuntu2 libopenjfx-jni=8u161-b12-1ubuntu2 -y
    $SUDO apt-mark hold openjfx libopenjfx-java libopenjfx-jni -y
    $SUDO update-java-alternatives -s java-1.8.0-openjdk-amd64
  elif [ "$ID" == "centos" ]; then
    $SUDO yum -y install java-1.8.0-openjdk
    if [ ! -L /usr/lib/jvm/java-8-openjdk-amd64 ]; then
     ln -s /usr/lib/jvm/java-1.8.* /usr/lib/jvm/java-8-openjdk-amd64
    fi
  fi

  $SUDO sed -i '/JAVA_HOME="\/usr\/lib\/jvm\/java-11-openjdk-amd64"/c\JAVA_HOME="\/usr\/lib\/jvm\/java-8-openjdk-amd64"'  $AMS_BASE/antmedia
  $SUDO sed -i '/Environment=JAVA_HOME="\/usr\/lib\/jvm\/java-11-openjdk-amd64"/c\Environment=JAVA_HOME="\/usr\/lib\/jvm\/java-8-openjdk-amd64"'  $AMS_BASE/antmedia

else
  if [ "$ID" == "ubuntu" ]; then
    $SUDO apt-get update -y
    $SUDO apt-get install openjdk-11-jre-headless -y
    check
  fi
  echo "export JAVA_HOME=\/usr\/lib\/jvm\/java-11-openjdk-amd64/" >>~/.bashrc
  source ~/.bashrc
  export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64/
  echo "JAVA_HOME : $JAVA_HOME"
  find /usr/lib/jvm/ -maxdepth 1 -type d -iname "java-11*" | head -1 | xargs -i update-alternatives --set java {}/bin/java
fi

if ! [ -d $AMS_BASE ]; then
  $SUDO mv ant-media-server $AMS_BASE
  check
else
  $SUDO mv $AMS_BASE $BACKUP_DIR
  check
  $SUDO mv ant-media-server $AMS_BASE
  check
fi



# use ln because of the jcvr bug: https://stackoverflow.com/questions/25868313/jscv-cannot-locate-jvm-library-file
$SUDO mkdir -p $JAVA_HOME/lib/amd64
$SUDO ln -sfn $JAVA_HOME/lib/server $JAVA_HOME/lib/amd64/


if [ "$INSTALL_SERVICE" == "true" ]; then

  if ! [ -x "$(command -v systemctl)" ]; then
    $SUDO cp $AMS_BASE/antmedia /etc/init.d
    $SUDO update-rc.d antmedia defaults
    $SUDO update-rc.d antmedia enable
    check
  else
    $SUDO chmod 644 $AMS_BASE/antmedia.service
    $SUDO cp -p $AMS_BASE/antmedia.service /etc/systemd/system/
    if [ "$OTHER_DISTRO" == "true" ]; then
      sed -i "s#=JAVA_HOME.*#=JAVA_HOME=$CUSTOM_JVM#g" $SERVICE_FILE
    fi
    if [ "aarch64" == $ARCH ]; then
      $SUDO update-java-alternatives -s java-1.11.*-openjdk-arm64
      sed -i "s#=JAVA_HOME.*#=JAVA_HOME=$DEFAULT_JAVA_ARM#g" $SERVICE_FILE
    fi
    $SUDO systemctl daemon-reload
    $SUDO systemctl enable antmedia
    check
  fi
fi

# create log directory if not exist
if [ ! -d "$LOG_DIRECTORY" ]
then
    #delete if there is a symbolic link or something
    $SUDO rm -rf $LOG_DIRECTORY
    #create log
    $SUDO mkdir $LOG_DIRECTORY
fi

# create a logrotate config file
cat << EOF > /etc/logrotate.d/antmedia
/var/log/antmedia/antmedia-error.log {
    daily
    create 644 antmedia antmedia
    rotate 7
    maxsize 50M
    compress
    delaycompress
    copytruncate
    notifempty
    sharedscripts
    postrotate
       reload rsyslog >/dev/null 2>&1 || true
    endscript
}
EOF

$SUDO ln -sf $LOG_DIRECTORY $AMS_BASE/log
check

$SUDO touch $AMS_BASE/log/antmedia-error.log
check

OS=`uname | tr "[:upper:]" "[:lower:]"`
PLATFORM=$OS-$ARCH

echo "PLATFORM:$PLATFORM"

if [ -d "$AMS_BASE/lib/native-$PLATFORM" ] ; then
  $SUDO mv $AMS_BASE/lib/native-$PLATFORM $AMS_BASE/lib/native
  $SUDO rm -r $AMS_BASE/lib/native-*
fi

if ! [ $(getent passwd | grep antmedia.*$AMS_BASE) ] ; then
  $SUDO useradd -d $AMS_BASE/ -s /bin/false -r antmedia
  check
fi

$SUDO chown -R antmedia:antmedia $AMS_BASE/
check
$SUDO chown -R antmedia:antmedia $LOG_DIRECTORY
check

if [ "$INSTALL_SERVICE" == "true" ]; then
  $SUDO service antmedia stop &
  wait $!
  $SUDO service antmedia start
  check
fi

if [ $? -eq 0 ]; then
  if [ $SAVE_SETTINGS == "true" ]; then
    sleep 5
    restore_settings
    check
    $SUDO chown -R antmedia:antmedia $AMS_BASE/
    check

    if [ "$INSTALL_SERVICE" == "true" ]; then
      $SUDO service antmedia restart
      check
    fi
  fi

  if [ "$INSTALL_SERVICE" == "false" ]; then
     echo "Ant Media Server is installed. You have the whole control and manage to run the start.sh in the $AMS_BASE"
     echo "because you prefer to not have the service installation. Type $0 -h for usage info "
  else
     echo "Ant Media Server is installed and started."
  fi
else
  echo "There is a problem in installing the ant media server. Please send the log of this console to support@antmedia.io"
fi
