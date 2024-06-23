#!/bin/bash


# To install latest snapshot version give --snapshot parameter
# sudo ./install_media-push-plugin.sh  --snapshot
# To install latest version just call directly
# sudo ./install_media-push-plugin.sh 



# Function to install Google Chrome on Debian-based systems
install_chrome_debian() {
    sudo apt-get update -y
    sudo apt-get install -y wget gnupg2
    #wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    #sudo dpkg -i google-chrome-stable_current_amd64.deb
    wget https://mirror.cs.uchicago.edu/google-chrome/pool/main/g/google-chrome-stable/google-chrome-stable_120.0.6099.199-1_amd64.deb
    sudo dpkg -i google-chrome-stable_120.0.6099.199-1_amd64.deb
    sudo apt-get install -f -y
    rm google-chrome-stable_current_amd64.deb
}

# Function to install Google Chrome on Red Hat-based systems
install_chrome_redhat() {
    cat <<EOF | sudo tee /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=http://dl.google.com/linux/chrome/rpm/stable/\$basearch
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
    sudo yum install -y google-chrome-stable
}

# Detect the Linux distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" = "debian" ] || [ "$ID" = "ubuntu" ]; then
        install_chrome_debian
    elif [ "$ID" = "centos" ] || [ "$ID" = "fedora" ]; then
        install_chrome_redhat
    else
        echo "Unsupported Linux distribution: $ID"
        exit 1
    fi
else
    echo "Cannot detect the Linux distribution."
    exit 1
fi

echo "Google Chrome installation is complete."

# Release URL
releaseUrl="https://oss.sonatype.org/service/local/repositories/releases/content/io/antmedia/plugin/media-push/maven-metadata.xml"
# Snapshot URL
snapshotUrl="https://oss.sonatype.org/service/local/repositories/snapshots/content/io/antmedia/plugin/media-push/maven-metadata.xml"


REDIRECT="releases"

while [[ "$1" != "" ]]; do
    case $1 in
        --snapshot) REDIRECT="snapshots" ;;
        *) echo "Invalid option: $1" ; exit 1 ;;
    esac
    shift
done

if [ "$REDIRECT" = "snapshots" ]; then
    echo "Installing snapshot version..."
    wget -O maven-metadata.xml $snapshotUrl
    if [ $? -ne 0 ]; then
      echo "There is a problem in getting the version of the media push plugin."
      exit $?
    fi
else
    echo "Installing latest version..."
    # Attempt to download from the release URL
    wget -O maven-metadata.xml $releaseUrl -q
    # Check if wget failed (e.g., 404 error)
    if [ $? -ne 0 ]; then
        echo "Release URL failed (404). Trying the snapshot URL..."
        wget -O maven-metadata.xml $snapshotUrl
        if [ $? -ne 0 ]; then
            echo "There is a problem in getting the version of the media push plugin."
            exit $?
        fi
        REDIRECT="snapshots"
    fi
fi


LAST_INDEX=14
if [ "$REDIRECT" = "snapshots" ]; then
	LAST_INDEX=23
fi

export LATEST_VERSION=$(cat maven-metadata.xml | grep "<version>" | tail -n 1 |  xargs | cut -c 10-${LAST_INDEX})

wget -O media-push.jar "https://oss.sonatype.org/service/local/artifact/maven/redirect?r=${REDIRECT}&g=io.antmedia.plugin&a=media-push&v=${LATEST_VERSION}&e=jar" 

if [ $? -ne 0 ]; then
    echo "There is a problem in downloading the media push plugin. Please send the log of this console to support@antmedia.io"
    exit $?
fi

sudo mv media-push.jar /usr/local/antmedia/plugins/

# Check if the copy command was successful
if [ $? -eq 0 ]; then
	sudo chown antmedia:antmedia /usr/local/antmedia/plugins/media-push.jar
    echo "Media Push Plugin is installed successfully.Please restart the service to make it effective."
    echo "Run the command below to restart antmedia"
    echo "sudo service antmedia restart"
else
    echo "Media Push Plugin cannot be installed. Check the error above."
    exit $?;
fi
