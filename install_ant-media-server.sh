#!/bin/bash

#
# Download latest ant media server and run this script by giving the zip file
# ./install_ant-media-server.sh ant-media-server-*.zip
# If you want to save setting from previous installation add argument true
# ./install_ant-media-server.sh ant-media-server-*.zip true

# -s : install as a service or not
# -r : restore settings
# -i : ant media server zip file

# Keep failure reports beside the caller's working directory, even after cd.
INSTALL_WORKING_DIRECTORY="$PWD"

collect_failure_report() {
  local exit_code=$1 report_dir archive tar_status
  local -a diagnostic_sudo=()
  trap - EXIT
  if [ "$exit_code" -eq 0 ]; then
    return 0
  fi

  # Diagnostics must never replace the installer's original exit status.
  if command -v sudo >/dev/null 2>&1; then
    diagnostic_sudo=(sudo -n)
  fi
  report_dir=$(mktemp -d "$INSTALL_WORKING_DIRECTORY/antmedia-install-failure-$(date +%Y%m%d-%H%M%S)-XXXXXX") || {
    echo "Cannot create diagnostics in $INSTALL_WORKING_DIRECTORY. Please contact contact@antmedia.io (installer exit $exit_code)." >&2
    exit "$exit_code"
  }
  archive="$report_dir.tar.gz"
  (
    umask 077
    printf 'Installer exit code: %s\nCollected at: %s\n' "$exit_code" "$(date -u)" > "$report_dir/installation.txt"
    {
      cat /etc/os-release
      uname -a
      command -v lscpu >/dev/null 2>&1 && lscpu
      free -h
      df -h
      java -version
    } > "$report_dir/system-info.txt" 2>&1
    if command -v systemctl >/dev/null 2>&1; then
      timeout 20 "${diagnostic_sudo[@]}" systemctl status antmedia --no-pager --full > "$report_dir/service-status.txt" 2>&1
      timeout 20 "${diagnostic_sudo[@]}" journalctl -u antmedia -n 500 --no-pager > "$report_dir/service-journal.txt" 2>&1
    else
      timeout 20 "${diagnostic_sudo[@]}" service antmedia status > "$report_dir/service-status.txt" 2>&1
    fi
    if [ -d "${LOG_DIRECTORY:-/var/log/antmedia}" ]; then
      timeout 60 "${diagnostic_sudo[@]}" cp -a "${LOG_DIRECTORY:-/var/log/antmedia}" "$report_dir/logs" > "$report_dir/log-collection.txt" 2>&1
    else
      echo "Ant Media log directory does not exist yet." > "$report_dir/log-collection.txt"
    fi
    "${diagnostic_sudo[@]}" tar -czf - -C "$report_dir" . > "$archive"
  )
  tar_status=$?
  if [ "$tar_status" -eq 0 ]; then
    "${diagnostic_sudo[@]}" rm -rf -- "$report_dir"
    printf '\033[0;31m%s\033[0m\n' "Installation failed (exit $exit_code). Diagnostic archive: $archive" >&2
    printf '\033[0;31m%s\033[0m\n' "Please email this archive to contact@antmedia.io." >&2
  else
    echo "Could not finish the diagnostic archive. Collected files: $report_dir" >&2
    echo "Please contact contact@antmedia.io and include these files." >&2
  fi
  exit "$exit_code"
}

trap 'collect_failure_report "$?"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

AMS_BASE=/usr/local/antmedia
BACKUP_DIR="/usr/local/antmedia-backup-"$(date +"%Y-%m-%d_%H-%M-%S")
SAVE_SETTINGS=false
INSTALL_SERVICE=true
ANT_MEDIA_SERVER_ZIP_FILE=
OTHER_DISTRO=false
SERVICE_FILE=/etc/systemd/system/antmedia.service
DEFAULT_JAVA="$(readlink -f "$(which java)" 2> /dev/null | rev | cut -d "/" -f3- | rev)"
LOG_DIRECTORY="/var/log/antmedia"
TOTAL_DISK_SPACE="$(df / --total -k -m --output=avail | tail -1 | xargs)"
ARCH=`uname -m`
RED='\033[0;31m'
NC='\033[0m' 
#version that is being installed. It's get filled below
VERSION= 
PRIVATE_IP=$(hostname -I | awk '{print $1}')
PUBLIC_IP=$(curl -s http://checkip.amazonaws.com)

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
  echo "  -l -> Activate the license."

  echo ""
  echo "Sample usage:"
  echo "$0 -i name-of-the-ant-media-server-zip-file"
  echo "$0 -i name-of-the-ant-media-server-zip-file -r true -s true"
  echo "$0 -i name-of-the-ant-media-server-zip-file -i false"
  echo "$0 -i name-of-the-ant-media-server-zip-file -d true"
  echo "$0 -i name-of-the-ant-media-server-zip-file -l \"XXXX-XXXX-XXXX\" "
  echo "$0 -u"
  echo ""
}

SUDO="sudo"
if ! [ -x "$(command -v sudo)" ]; then
  SUDO=""
fi

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

  local restore_deadline=$((SECONDS + 120))
  for i in ${webapps[*]}; do
        while [ ! -d $AMS_BASE/webapps/$i/WEB-INF/ ]; do
                if (( SECONDS >= restore_deadline )); then
                  echo "Timed out waiting for application directories during settings restore." >&2
                  startup_failed
                fi
                sleep 1
        done
        if [ -d $BACKUP_DIR/webapps/$i/ ]; then
          cp -p -r $BACKUP_DIR/webapps/$i/WEB-INF/red5-web.properties $AMS_BASE/webapps/$i/WEB-INF/red5-web.properties
          check
          if [ -d $BACKUP_DIR/webapps/$i/streams/ ]; then
            if [ -L $BACKUP_DIR/webapps/$i/streams ]; then
              ii=`echo $BACKUP_DIR/webapps/$i/streams | cut -d "/" -f 6`
              ln -sf $(readlink -f $BACKUP_DIR/webapps/$i/streams) $AMS_BASE/webapps/$ii/streams
              check
            else
              cp -p -r $BACKUP_DIR/webapps/$i/streams/ $AMS_BASE/webapps/$i/
              check
            fi
          fi
        fi
  done

  diff_webapps=$(diff <(ls $AMS_BASE/webapps/) <(ls $BACKUP_DIR/webapps/) | awk -F">" '{print $2}' | xargs)

  if [ ! -z "$diff_webapps" ]; then
    for custom_app in $diff_webapps; do
      mkdir $AMS_BASE/webapps/$custom_app
      check
      unzip $AMS_BASE/StreamApp*.war -d $AMS_BASE/webapps/$custom_app
      check
      sleep 2
      cp -p $BACKUP_DIR/webapps/$custom_app/WEB-INF/red5-web.properties $AMS_BASE/webapps/$custom_app/WEB-INF/red5-web.properties
      check
      if [ -d $BACKUP_DIR/webapps/$custom_app/streams/ ]; then
        cp -p -r $BACKUP_DIR/webapps/$custom_app/streams/ $AMS_BASE/webapps/$custom_app/
        check
      fi
    done
  fi

  
  find $BACKUP_DIR/ -type f -iname "*.db" -exec cp -p {} $AMS_BASE/ \;
  #jee-container holds beans. SSL restoring and cluster restorign require coping
  cp -p "$BACKUP_DIR/conf/"{red5.properties,jee-container.xml} "$AMS_BASE/conf"
  check
  
  #tokenGenerator has been removed in 2.6 so remove the tokenGeneraator class from the jee-container in 2.6 and later version
  TOKEN_GENERATOR_REMOVED_VERSION=2.6
  if [ "$(printf '%s\n' "$TOKEN_GENERATOR_REMOVED_VERSION" "$VERSION" | sort -V | head -n1)" == "$TOKEN_GENERATOR_REMOVED_VERSION" ]; then
  	#remove token generator from jee-container.xml
  	$SUDO sed -i '/<bean[[:space:]]*id="tokenGenerator"[[:space:]]*class="io.antmedia.filter.TokenGenerator"[[:space:]]*\/>/d' $AMS_BASE/conf/jee-container.xml
    check
	$SUDO sed -i '/<property[[:space:]]*name="tokenGenerator"[[:space:]]*ref="tokenGenerator"[[:space:]]*\/>/d' $AMS_BASE/conf/jee-container.xml
	check
  fi

  #SSL Restore
  if [ $(grep -o -E '<!-- https start -->|<!-- https end -->' $BACKUP_DIR/conf/jee-container.xml  | wc -l) == "2" ]; then
    cp -p $BACKUP_DIR/conf/{chain.pem,privkey.pem,fullchain.pem,truststore.jks,keystore.jks} $AMS_BASE/conf/
    check
  fi

  if [ $(grep 'nativeLogLevel=' $AMS_BASE/conf/red5.properties | wc -l) == "0" ]; then
    $SUDO echo "nativeLogLevel=ERROR" >> $AMS_BASE/conf/red5.properties
  fi


  if [ $(grep 'http.ssl_certificate_chain_file=' $AMS_BASE/conf/red5.properties | wc -l) == "0" ]; then
    $SUDO echo "http.ssl_certificate_chain_file=conf/chain.pem" >> $AMS_BASE/conf/red5.properties
  fi

  if [ $(grep 'SSLCertificateChainFile' $AMS_BASE/conf/jee-container.xml | wc -l) == "0" ]; then
    $SUDO sed -i '/<entry key="SSLCertificateFile.*/a <entry key="SSLCertificateChainFile" value="${http.ssl_certificate_chain_file}" />' $AMS_BASE/conf/jee-container.xml
    check
  fi

  # This is a fix in upgrading versions that uses Http11Nio2Protocol
  # I think we can delete the following two lines after 6 months because it will become useless. 
  # Sep 25, 21 - mekya
  if [ $(grep 'Http11AprProtocol' $AMS_BASE/conf/jee-container.xml | wc -l) != "0" ]; then
    $sudo sed -i 's/org.apache.coyote.http11.Http11AprProtocol/org.apache.coyote.http11.Http11Nio2Protocol/g' $AMS_BASE/conf/jee-container.xml
    check
  fi


  if [ $? -eq "0" ]; then
    echo "Settings are restored."
  else
    echo "Settings are not restored. Please send the diagnostic report to contact@antmedia.io"
  fi
}
#Get the linux distribution
distro () {
  os_release="/etc/os-release"
  if [ -f "$os_release" ]; then
    . $os_release
    msg="We are supporting Ubuntu 20.04, Ubuntu 22.04, Ubuntu 24.04, Ubuntu 26.04, CentOS Stream 9/10, RockyLinux 9/10, AlmaLinux 9/10 and Debian 12/13"
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
        check
        CUSTOM_JVM=$DEFAULT_JAVA
      fi
    elif [ "$ID" == "ubuntu" ] || [ "$ID" == "centos" ] || [ "$ID" == "rocky" ] || [ "$ID" == "almalinux" ] || [ "$ID" == "rhel" ] || [ "$ID" == "debian" ]; then
      if [ "$VERSION_ID" == "18.04" ] && [ "aarch64" == $ARCH ]; then
        echo -e "ARM architecture is supported on Ubuntu 20.04. For 18.04 installation, use the link below to install.\nhttps://github.com/ant-media/Ant-Media-Server/wiki/Frequently-Asked-Questions#how-can-i-install-the-ant-media-server-on-ubuntu-1804-with-arm64"
        exit 1
      fi

      if [[ $VERSION_ID != 20.04 ]] && [[ $VERSION_ID != 22.04 ]] && [[ $VERSION_ID != 24.04 ]] && [[ $VERSION_ID != 26.04 ]] && [[ $VERSION_ID != 10 ]] && [[ $VERSION_ID != 10.* ]] && [[ $VERSION_ID != 9* ]] && [[ $VERSION_ID != 12 ]] && [[ $VERSION_ID != 13 ]]; then
         echo $msg
         exit 1
            fi
    else
      echo $msg
      exit 1
    fi
  fi
}

check_version() {
  if [ "$VERSION_ID" = "22.04" ]; then
      echo -e "${RED}You can install AMS v2.6 or higher on Ubuntu 22.04${NC}"
      exit 1
  fi
  if [[ "$VERSION_ID" == 9 || "$VERSION_ID" == 9.* || "$VERSION_ID" == 10 || "$VERSION_ID" == 10.* ]]; then
      echo -e "${RED}You can install AMS v2.6 or higher on CentOS/AlmaLinux/RockyLinux 9/10${NC}"
      exit 1
  fi
}

check_enterprise_file() {
  local retry_count=0
  local max_retries=3
  local remote_file
  local local_file

  while [ $retry_count -lt $max_retries ]; do

    remote_file="$(curl -sL https://antmedia.io/download/latest-version.md5 | cut -d ' ' -f 1)"
    local_file="$(md5sum "$ANT_MEDIA_SERVER_ZIP_FILE" | cut -d ' ' -f 1)"

    if [ "$local_file" != "$remote_file" ]; then
      echo "Downloaded file MD5 checksum is different from remote file MD5 checksum. Retrying download. Attempt: $((retry_count+1))"
      curl --progress-bar -o "$ANT_MEDIA_SERVER_ZIP_FILE" "$check_license"
      ((retry_count++))
    else
      echo "Downloaded file MD5 checksum matches remote file MD5 checksum."
      return 0 
    fi
  done

  echo "Failed to download the file after $max_retries attempts. Please re-run script again or check the internet connection"
  exit 1 
}

#Just checks if the latest ioperation is successfull
check() {
  local OUT=$?
  if [ $OUT -ne 0 ]; then
    printf '\033[0;31m%s\033[0m\n' "Installation failed near line ${BASH_LINENO[0]} (exit $OUT). A diagnostic report will be collected" >&2
    exit $OUT
  fi
}

# Print diagnostics without hiding the original failure.
startup_failed() {
  echo "Ant Media Server failed to become ready." >&2
  exit 1
}

service_running() {
  if command -v systemctl >/dev/null 2>&1; then
    $SUDO systemctl is-active --quiet antmedia || return 1
    local pid
    pid=$($SUDO systemctl show antmedia --property=MainPID --value) || return 1
    [[ "$pid" =~ ^[1-9][0-9]*$ ]] || return 1
    $SUDO kill -0 "$pid" 2>/dev/null
  else
    $SUDO service antmedia status >/dev/null 2>&1
  fi
}

# Require three consecutive ready checks, with a bounded startup wait.
wait_for_server() {
  local port url code consecutive=0 deadline=$((SECONDS + 120))
  port=$(sed -n 's/^[[:space:]]*http.port[[:space:]]*=[[:space:]]*//p' "$AMS_BASE/conf/red5.properties" | tail -n 1 | tr -d '\r[:space:]')
  port=${port:-5080}
  PANEL_PORT=$port
  url="http://127.0.0.1:$port/"
  echo "Waiting for Ant Media Server at $url (up to 120 seconds)..."
  while (( SECONDS < deadline )); do
    code=$(curl --noproxy '*' --silent --output /dev/null --write-out '%{http_code}' --connect-timeout 2 --max-time 3 "$url") || code=000
    if service_running && [[ "$code" =~ ^[23][0-9][0-9]$ ]]; then
      consecutive=$((consecutive + 1))
      if (( consecutive >= 3 )); then
        return 0
      fi
    else
      consecutive=0
    fi
    sleep 2
  done
  startup_failed
}

# Reuse a working Java 21 on Debian before attempting package installation.
setup_debian_java21() {
  local candidate output package_candidate download_dir java_bin
  DEBIAN_JAVA_HOME=""
  for candidate in "${JAVA_HOME:-}" /usr/lib/jvm/*; do
    [ -x "$candidate/bin/java" ] || continue
    output=$("$candidate/bin/java" -version 2>&1) || continue
    if grep -qE '^(openjdk|java) version "21(\.|")' <<< "$output"; then
      DEBIAN_JAVA_HOME=$(readlink -f "$candidate")
      return 0
    fi
  done

  if [ "$VERSION_ID" == "12" ] && [ "$ARCH" == "aarch64" ]; then
    echo "Java 21 was not found. Automatic Java 21 installation on Debian 12 ARM64 is not supported yet. Install Java 21 manually and rerun this script." >&2
    exit 1
  fi

  $SUDO apt-get update -y
  check
  package_candidate=$(LC_ALL=C apt-cache policy openjdk-21-jre-headless | awk '/Candidate:/ {print $2}')
  if [ -n "$package_candidate" ] && [ "$package_candidate" != "(none)" ]; then
    $SUDO apt-get install openjdk-21-jre-headless -y
    check
    DEBIAN_JAVA_HOME="/usr/lib/jvm/java-21-openjdk-${JVM_DEBIAN_ARCH}"
  elif [ "$ARCH" == "x86_64" ]; then
    download_dir=$(mktemp -d)
    check
    curl -fL --retry 3 -o "$download_dir/jdk.deb" https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.deb
    check
    curl -fL --retry 3 -o "$download_dir/jdk.sha256" https://download.oracle.com/java/21/latest/jdk-21_linux-x64_bin.deb.sha256
    check
    (cd "$download_dir" && printf '%s  jdk.deb\n' "$(awk '{print $1}' jdk.sha256)" | sha256sum -c -)
    check
    $SUDO mkdir -p /usr/share/binfmts
    check
    $SUDO apt-get install -y "$download_dir/jdk.deb"
    check
    java_bin=$(dpkg-query -L jdk-21 | awk '/\/bin\/java$/ {print}')
    if [ -z "$java_bin" ] || [[ "$java_bin" == *$'\n'* ]] || [ ! -x "$java_bin" ]; then
      echo "Could not locate the installed Oracle Java 21 executable." >&2
      exit 1
    fi
    DEBIAN_JAVA_HOME=$(dirname "$(dirname "$java_bin")")
    rm -rf -- "$download_dir"
  else
    echo "Java 21 is unavailable from the configured repositories for $ARCH. Install Java 21 manually and rerun this script." >&2
    exit 1
  fi
  output=$("$DEBIAN_JAVA_HOME/bin/java" -version 2>&1)
  check
  grep -qE '^(openjdk|java) version "21(\.|")' <<< "$output"
  check
}

# Start

while getopts 'i:s:r:d:l:hu' option
do
  case "${option}" in
    s) INSTALL_SERVICE=${OPTARG};;
    i) ANT_MEDIA_SERVER_ZIP_FILE=${OPTARG};;
    r) SAVE_SETTINGS=${OPTARG};;
    d) OTHER_DISTRO=${OPTARG};;
    u) UPDATE="true";;
    l) LICENSE_KEY=${OPTARG};;
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
  if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
    #Added curl package for the minimal OS installations.
    $SUDO apt-get update
    check
    $SUDO apt-get install jq curl -y
    check
  elif [ "$ID" == "centos" ] || [ "$ID" == "almalinux" ] || [ "$ID" == "rocky" ] || [ "$ID" == "rhel" ]; then
    # Replace curl-minimal with the full curl package when necessary.
    $SUDO yum -y --allowerasing install jq curl
    check
  fi
  if [ -z "${LICENSE_KEY}" ]; then
    echo "Downloading the latest version of Ant Media Server Community Edition."
    curl --progress-bar -o ams_community.zip -L "$(curl -s -H "Accept: application/vnd.github+json" https://api.github.com/repos/ant-media/Ant-Media-Server/releases/latest | jq -r '.assets[0].browser_download_url')"   
    ANT_MEDIA_SERVER_ZIP_FILE="ams_community.zip"
  elif [ -n "${LICENSE_KEY}" ]; then
    check_license=$(curl -s https://api-v2.antmedia.io/?license="${LICENSE_KEY}" | tr -d "\"")
    if [ "$check_license" == "401" ]; then
      echo "Invalid license key. Please check your license key."
      exit 1
    else
      VERSION_NAME=$(curl -s https://antmedia.io/download/latest-version.json | jq -r '.versionName')
      echo "The license key is valid. Downloading the latest version ($VERSION_NAME) of Ant Media Server Enterprise Edition."
      curl --progress-bar -o ams_enterprise.zip "$check_license"
      ANT_MEDIA_SERVER_ZIP_FILE="ams_enterprise.zip"
      check_enterprise_file
    fi
  fi
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

REQUIRED_VERSION="2.6"

if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
  $SUDO apt-get update -y
  check
  $SUDO apt-get install curl unzip zip libva-drm2 libva-x11-2 libvdpau-dev -y
  check
  $SUDO unzip -o $ANT_MEDIA_SERVER_ZIP_FILE "ant-media-server/ant-media-server.jar" -d /tmp/
  check
  VERSION=$(unzip -p /tmp/ant-media-server/ant-media-server.jar | grep -a "Implementation-Version"|cut -d' ' -f2 | tr -d '\r')
    
  # If the version is lower than 2.6 and the architecture is x86_64, install the libcrystalhd-dev package. 
  # Additionally, arm64 architecture does not have libcrystalhd-dev and the following check will fix the installation problem in ARM.
  # After 2.6, there is no dependency to libcrystalhd-dev
  if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
      check_version
      if [ "x86_64" == $ARCH ]; then
        $SUDO apt-get install libcrystalhd-dev -y
        check
      fi
  fi
elif [ "$ID" == "centos" ] || [ "$ID" == "rocky" ] || [ "$ID" == "almalinux" ] || [ "$ID" == "rhel" ]; then
  $SUDO yum -y install epel-release
  check
  # Minimal RPM images ship curl-minimal, which conflicts with full curl.
  $SUDO yum -y --allowerasing install curl unzip zip libva libvdpau
  check
  $SUDO unzip -o $ANT_MEDIA_SERVER_ZIP_FILE "ant-media-server/ant-media-server.jar" -d /tmp/
  check
  VERSION=$(unzip -p /tmp/ant-media-server/ant-media-server.jar | grep -a "Implementation-Version"|cut -d' ' -f2 | tr -d '\r')
  if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    check_version
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


if [[ $VERSION == 2.1\.+.* || $VERSION == 2.0* || $VERSION == 1.* ]]; then
  if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
    $SUDO apt-get install openjdk-8-jre -y
    check
    $SUDO apt purge openjfx libopenjfx-java libopenjfx-jni -y
    $SUDO apt install openjfx=8u161-b12-1ubuntu2 libopenjfx-java=8u161-b12-1ubuntu2 libopenjfx-jni=8u161-b12-1ubuntu2 -y
    $SUDO apt-mark hold openjfx libopenjfx-java libopenjfx-jni -y
    $SUDO update-java-alternatives -s java-1.8.0-openjdk-amd64
  elif [ "$ID" == "centos" ]; then
    $SUDO yum -y install java-1.8.0-openjdk
    check
    if [ ! -L /usr/lib/jvm/java-8-openjdk-amd64 ]; then
     ln -s /usr/lib/jvm/java-1.8.* /usr/lib/jvm/java-8-openjdk-amd64
    fi
  fi

  $SUDO sed -i '/JAVA_HOME="\/usr\/lib\/jvm\/java-11-openjdk-amd64"/c\JAVA_HOME="\/usr\/lib\/jvm\/java-8-openjdk-amd64"'  $AMS_BASE/antmedia
  $SUDO sed -i '/Environment=JAVA_HOME="\/usr\/lib\/jvm\/java-11-openjdk-amd64"/c\Environment=JAVA_HOME="\/usr\/lib\/jvm\/java-8-openjdk-amd64"'  $AMS_BASE/antmedia

elif [[ $VERSION == 2.4* || $VERSION == 2.3* || $VERSION == 2.2* ]]; then
	
  if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
    $SUDO apt-get update -y
    check
    $SUDO apt-get install openjdk-11-jdk -y
    check
  fi
 
elif [[ $VERSION == 2.5* || $VERSION == 2.6* || $VERSION == 2.7* ]]; then
  if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
    $SUDO apt-get update -y
    check
    $SUDO apt-get install openjdk-11-jre-headless -y
    check
  elif [ "$ID" == "centos" ] || [ "$ID" == "almalinux" ] || [ "$ID" == "rocky" ] || [ "$ID" == "rhel" ]; then
    $SUDO yum -y install java-11-openjdk-headless tzdata-java
    check
    ln -s $(readlink -f $(which java) | rev | cut -d "/" -f3- | rev) /usr/lib/jvm/java-11-openjdk-amd64
  fi 
  echo "export JAVA_HOME=\/usr\/lib\/jvm\/java-11-openjdk-amd64/" >>~/.bashrc
  source ~/.bashrc
  export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64/
  echo "JAVA_HOME : $JAVA_HOME"
  find /usr/lib/jvm/ -maxdepth 1 -type d -iname "java-11*" | head -1 | xargs -i update-alternatives --set java {}/bin/java

elif [ "$(printf '%s\n' "2.8" "$VERSION" | sort -V | head -n1)" = "2.8" ] && [ "$(printf '%s\n' "3.1" "$VERSION" | sort -V | head -n1)" != "3.1" ]; then
  # AMS 2.8 and later, up to 3.1, use Java 17.
  if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
    $SUDO apt-get update -y
    check
    $SUDO apt-get install openjdk-17-jre-headless -y
    check
    
    #install packages for SSL to speed up setting up the SSL especially for AWS auto-managed solution
    $SUDO apt-get install cron certbot python3-certbot-dns-route53 jq dnsutils iptables -qq -y
    check
  elif [ "$ID" == "centos" ] || [ "$ID" == "almalinux" ] || [ "$ID" == "rocky" ] || [ "$ID" == "rhel" ]; then
    $SUDO yum -y install java-17-openjdk-headless tzdata-java
    check
    $SUDO rm -rf /usr/lib/jvm/java-17-openjdk-amd64
    JAVA_PATH=$($SUDO alternatives --display java | grep 'link currently points to' | awk '{print $5}' | awk -F'/bin/java' '{print $1}')
    $SUDO ln -sf $JAVA_PATH /usr/lib/jvm/java-17-openjdk-amd64
    check
  fi 
  echo "export JAVA_HOME=\/usr\/lib\/jvm\/java-17-openjdk-amd64/" >>~/.bashrc
  source ~/.bashrc
  export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64/
  echo "JAVA_HOME : $JAVA_HOME"
  find /usr/lib/jvm/ -maxdepth 1 -type d -iname "java-17*" | head -1 | xargs -i update-alternatives --set java {}/bin/java

elif [ "$(printf '%s\n' "3.1" "$VERSION" | sort -V | head -n1)" = "3.1" ]; then
  # AMS 3.1 and later require Java 21.
  if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
    if [ "$ID" == "debian" ]; then
      JVM_DEBIAN_ARCH=$(dpkg --print-architecture)
      check
      setup_debian_java21
    else
      $SUDO apt-get update -y
      check
      $SUDO apt-get install openjdk-21-jre-headless -y
      check
    fi

    #install packages for SSL to speed up setting up the SSL especially for AWS auto-managed solution
    $SUDO apt-get install cron certbot python3-certbot-dns-route53 jq dnsutils iptables -qq -y
    check
  elif [ "$ID" == "centos" ] || [ "$ID" == "almalinux" ] || [ "$ID" == "rocky" ] || [ "$ID" == "rhel" ]; then
    $SUDO yum -y install java-21-openjdk-headless tzdata-java
    check
    $SUDO rm -rf /usr/lib/jvm/java-21-openjdk-amd64
    JAVA_PATH=$($SUDO alternatives --display java | grep 'link currently points to' | awk '{print $5}' | awk -F'/bin/java' '{print $1}')
    $SUDO ln -sf $JAVA_PATH /usr/lib/jvm/java-21-openjdk-amd64
    check
  fi
  echo "export JAVA_HOME=${DEBIAN_JAVA_HOME:-/usr/lib/jvm/java-21-openjdk-amd64/}" >>~/.bashrc
  source ~/.bashrc
  export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64/
  if [ -n "$DEBIAN_JAVA_HOME" ]; then
    export JAVA_HOME="$DEBIAN_JAVA_HOME"
    java_service_home="/usr/lib/jvm/java-21-openjdk-${JVM_DEBIAN_ARCH}"
    if [ "$(readlink -f "$java_service_home")" != "$JAVA_HOME" ]; then
      $SUDO ln -sfnT "$JAVA_HOME" "$java_service_home"
      check
    fi
    $SUDO update-alternatives --set java "$JAVA_HOME/bin/java"
    check
  fi
  echo "JAVA_HOME : $JAVA_HOME"
  if [ "$ID" != "debian" ]; then
  find /usr/lib/jvm/ -maxdepth 1 -type d -iname "java-21*" | head -1 | xargs -i update-alternatives --set java {}/bin/java
  fi
	
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
check
$SUDO ln -sfn $JAVA_HOME/lib/server $JAVA_HOME/lib/amd64/
check


if [ "$INSTALL_SERVICE" == "true" ]; then

  if ! [ -x "$(command -v systemctl)" ]; then
    $SUDO cp $AMS_BASE/antmedia /etc/init.d
    check
    $SUDO update-rc.d antmedia defaults
    check
    $SUDO update-rc.d antmedia enable
    check
  else
    $SUDO chmod 644 $AMS_BASE/antmedia.service
    check
    $SUDO cp -p $AMS_BASE/antmedia.service /etc/systemd/system/
    check
    if [ "$OTHER_DISTRO" == "true" ]; then
      sed -i "s#=JAVA_HOME.*#=JAVA_HOME=$CUSTOM_JVM#g" $SERVICE_FILE
    fi
    if [ "aarch64" == $ARCH ]; then
      $SUDO update-java-alternatives -s java-1.11.*-openjdk-arm64
      sed -i "s#=JAVA_HOME.*#=JAVA_HOME=$DEFAULT_JAVA_ARM#g" $SERVICE_FILE
    fi
    echo 'antmedia ALL=(ALL) NOPASSWD: /bin/bash enable_ssl.sh*' | $SUDO tee /etc/sudoers.d/antmedia > /dev/null
    check
    $SUDO systemctl daemon-reload
    check
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
    check
fi

# create a logrotate config file
cat << EOF | $SUDO tee /etc/logrotate.d/antmedia > /dev/null
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
/var/log/antmedia/0.0.0.0_access*.log {
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
check

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

# Set the license key before starting the service.
if [ -n "${LICENSE_KEY}" ]; then
  $SUDO sed -i "s/server.licence_key=.*/server.licence_key=${LICENSE_KEY}/" "$AMS_BASE/conf/red5.properties"
  check
fi

if [ "$INSTALL_SERVICE" == "true" ]; then
  $SUDO service antmedia stop &
  wait $!
  $SUDO service antmedia start || startup_failed
fi

if [ "$?" -eq "0" ]; then
  if [ "$SAVE_SETTINGS" == "true" ]; then
    sleep 5
    restore_settings
    check
    $SUDO chown -R antmedia:antmedia $AMS_BASE/
    check

    if [ "$INSTALL_SERVICE" == "true" ]; then
      $SUDO service antmedia restart || startup_failed
    fi
  fi

  if [ "$INSTALL_SERVICE" == "false" ]; then
     echo "Ant Media Server is installed. You have the whole control and manage to run the start.sh in the $AMS_BASE"
     echo "because you prefer to not have the service installation. Type $0 -h for usage info "
  else
     wait_for_server
     echo "Ant Media Server is installed and started."
  fi
else
  echo "There is a problem in installing the ant media server. Please send the diagnostic report to contact@antmedia.io" >&2
  exit 1
fi

echo ""
echo "============================================================"
echo "✅ Ant Media Server installation completed successfully!"
echo "============================================================"
echo ""
if [ "$INSTALL_SERVICE" == "true" ]; then
echo "🌐 Access Ant Media Server Web Panel:"
echo ""
echo "🔹 Public IP:"
echo "   http://$PUBLIC_IP:$PANEL_PORT"
echo ""
echo "🔹 Private IP:"
echo "   http://$PRIVATE_IP:$PANEL_PORT"
echo ""
fi
echo "📘 Documentation:"
echo "   https://docs.antmedia.io/"
echo ""
echo "🆘 Support:"
echo "   support@antmedia.io"
echo ""
echo "============================================================"
echo "🎉 Happy Streaming with Ant Media Server!"
echo "============================================================"
