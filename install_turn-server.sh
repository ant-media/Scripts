#!/bin/bash

# Check if user is running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Function to install Coturn
install_coturn() {
    apt-get update
    apt-get install -y coturn
    truncate -s 0 /etc/turnserver.conf
}

# Function to generate random username
generate_credentials() {
    username=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 8 | head -n 1)
    password=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | fold -w 12 | head -n 1)
    echo "Username: $username"
    echo "Password: $password"
    echo "lt-cred-mech" >> /etc/turnserver.conf
    echo "user=$username:$password" >> /etc/turnserver.conf
}

# Function to configure Coturn for NAT network
configure_nat() {
    # Add necessary configuration options for NAT network
    echo 'TURNSERVER_ENABLED=1' >> /etc/default/coturn
    # Get public IP
    public_ip=$(curl -s http://checkip.amazonaws.com)
    
    # Get private IP
    private_ip=$(hostname -I | awk '{print $1}')
    
    # Add external IP configuration to turnserver.conf
    echo "external-ip=$public_ip/$private_ip" >> /etc/turnserver.conf
    echo "realm=$public_ip" >> /etc/turnserver.conf
}

# Function to configure Coturn for public IP
configure_public_ip() {
    # Add necessary configuration options for public IP
    echo 'TURNSERVER_ENABLED=1' >> /etc/default/coturn

    # Get public IP
    public_ip=$(curl -s http://checkip.amazonaws.com)
    
    # Add external IP configuration to turnserver.conf
    echo "realm=$public_ip" >> /etc/turnserver.conf
}

# Main script

# Prompt user for configuration option
echo "Choose the configuration option:"
echo "1. Behind NAT network (e.g., AWS)"
echo "2. Directly accessible public IP"
read -r -p "Enter your choice (1 or 2): " option

case $option in
    1)
        install_coturn
        generate_credentials
        configure_nat
        ;;
    2)
        install_coturn
        generate_credentials
        configure_public_ip
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

# Start and enable Coturn service
systemctl restart coturn
systemctl enable coturn

echo "Coturn installation and configuration completed."
