#!/bin/bash

#!/bin/bash

HTTP_PORT=5080
RTMP_PORT=1935
SRT_PORT=4200
NGINX_BASE_FILE_URL=https://raw.githubusercontent.com/ant-media/Scripts/master/nginx/nginx.conf

# Define default values for options
origin_server_ips=()
edge_server_ips=()
domain=""
email=""
ssl_enabled=""

# Function to display the script usage
function display_usage() {
  echo "Usage: $0 [-o origin_server_ips] [-e edge_server_ips] [-d domain_name] [-m email_address] [-s] [-c]"
  echo "Options:"
  echo "  -o origin_server_ips       Set origin server IP array (e.g., -o \"10.0.1.1,10.0.1.2,10.0.1.3\")"
  echo "  -e edge_server_ips         Set edge server IP array (e.g., -e \"10.0.0.1,10.0.0.2,10.0.0.3\")"
  echo "  -d domain_name             Set domain name (e.g., -d example.com)"
  echo "  -m email_address           Set email address for Let's Encrypt notifications (optional)"
  echo "  -s                         Enable SSL certificate installation. If domain name and email_address is defined, it becomes enabled"
  echo "  -c                         Create Nginx configuration only, without installing Nginx or SSL"
  echo ""
  echo "Usage Examples:"
  echo ""
  echo "1. Create Nginx configuration only:"
  echo "   $0 -o \"10.0.1.1,10.0.1.2,10.0.1.3\" -e \"10.0.0.1,10.0.0.2,10.0.0.3\" -d example.com -c"
  echo ""
  echo "2. Create Nginx configuration only with making SSL enabled in the Nginx configuration:"
  echo "   $0 -o \"10.0.1.1,10.0.1.2,10.0.1.3\" -e \"10.0.0.1,10.0.0.2,10.0.0.3\" -d example.com -c -s"
  echo ""
  echo "3. Install Nginx and generate Nginx configuration without installing SSL and without making SSL enabled in the Nginx configuration:"
  echo "   $0 -o \"10.0.1.1,10.0.1.2,10.0.1.3\" -e \"10.0.0.1,10.0.0.2,10.0.0.3\" -d example.com"
  echo ""
  echo "4. Install Nginx, generate Nginx configuration, and install SSL certificate:"
  echo "   $0 -o \"10.0.1.1,10.0.1.2,10.0.1.3\" -e \"10.0.0.1,10.0.0.2,10.0.0.3\" -d example.com -m user@example.com"
  echo ""
  echo "5. Install Nginx, generate Nginx configuration, and install SSL certificate:"
  echo "   $0 -o \"10.0.1.1,10.0.1.2,10.0.1.3\" -e \"10.0.0.1,10.0.0.2,10.0.0.3\" -d example.com -s -c"
}


# Function to update Nginx configuration
update_nginx_config() {
  local nginx_config="nginx.conf"
  local nginx_original="nginx.conf.original"

  if [ ! -f $nginx_original ]; then
  	
  	if wget -q --spider "$NGINX_BASE_FILE_URL"; then
	  echo "$NGINX_BASE_FILE_URL is available. Downloading..."
	  wget $NGINX_BASE_FILE_URL -O $nginx_original
	else
	  echo "$NGINX_BASE_FILE_URL Resource not found."
	  exit 1
	fi
   
  else
    echo "Original nginx configuration already exists. Skipping download."
  fi

  echo "Updating Nginx configuration..."

  sudo cp $nginx_original $nginx_config

  # Generate the server blocks configuration based on the IP addresses
  origin_server_blocks=""
  for ip in "${origin_server_ips[@]}"; do
    origin_server_blocks+="\n    server $ip:$HTTP_PORT;\n"
  done

  rtmp_origin_server_blocks=""
  for ip in "${origin_server_ips[@]}"; do
    rtmp_origin_server_blocks+="\n    server $ip:$RTMP_PORT;\n"
  done

  srt_origin_server_blocks=""
  for ip in "${origin_server_ips[@]}"; do
    srt_origin_server_blocks+="\n    server $ip:$SRT_PORT;\n"
  done

  edge_server_blocks=""
  for ip in "${edge_server_ips[@]}"; do
    edge_server_blocks+="\n    server $ip;\n"
  done

  sudo sed -i "s/{{ORIGIN_SERVER_BLOCKS}}/$origin_server_blocks/g" $nginx_config
  sudo sed -i "s/{{RTMP_SERVER_BLOCKS}}/$rtmp_origin_server_blocks/g" $nginx_config
  sudo sed -i "s/{{ORIGIN_SRT_SERVER_BLOCKS}}/$srt_origin_server_blocks/g" $nginx_config
  sudo sed -i "s/{{EDGE_SERVER_BLOCKS}}/$edge_server_blocks/g" $nginx_config
  sudo sed -i "s/{{YOUR_DOMAIN}}/$domain/g" $nginx_config
  
  # Check if a ssl enabled name is provided
  if [[ -n "$ssl_enabled"  ]]; then
    sudo sed -i 's/#ssl-disabled//g' $nginx_config
  fi

  echo "Nginx configuration updated."
}

# Function to install Nginx
install_nginx() {
  echo "Installing Nginx..."
  sudo apt-get update
  sudo apt-get install -y nginx
}

# Function to install Certbot and its dependencies
install_certbot() {
  echo "Installing Certbot and its dependencies..."
  sudo apt-get update
  sudo apt-get install -y certbot python3-certbot-nginx
}

# Function to obtain and install SSL certificate
install_ssl() {
  local domain=$1
  local email=$2
  local certbot_cmd="sudo certbot --nginx -d $domain --non-interactive --agree-tos"

  if [[ -n "$email" ]]; then
    certbot_cmd+=" --email $email"
  else
    certbot_cmd+=" --register-unsafely-without-email"
  fi

  echo "Obtaining and installing SSL certificate for domain: $domain"
  $certbot_cmd
}

# Function to restart Nginx
restart_nginx() {
  echo "Restarting Nginx..."
  sudo systemctl restart nginx
}

# Function to add crontab job for SSL renewal
add_crontab_job() {
  local job="$1"
  if ! crontab -l | grep -q "$job"; then
    (crontab -l 2>/dev/null; echo "$job") | crontab -
    echo "Added crontab job for SSL renewal."
  else
    echo "Crontab entry for SSL renewal already exists. Skipping crontab update."
  fi
}

# Check if required options are provided
if [[ $# -eq 0 ]]; then
  display_usage
  exit 1
fi

# Parse command-line options
while getopts ":o:e:d:m:cs" opt; do
  case $opt in
    o)
      IFS=',' read -ra origin_server_ips <<< "$OPTARG"
      ;;
    e)
      IFS=',' read -ra edge_server_ips <<< "$OPTARG"
      ;;
    d)
      domain=$OPTARG
      ;;
    m)
      email=$OPTARG
      ;;
    s)
      ssl_enabled=true
      ;;
    c)
      update_nginx_config
      echo "Nginx configuration created successfully."
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      display_usage
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      display_usage
      exit 1
      ;;
  esac
done

# Check if both origin and edge server IP arrays are provided
if [[ -z "${origin_server_ips[@]}" || -z "${edge_server_ips[@]}" ]]; then
  echo "Missing required options: -o origin_server_ips and -e edge_server_ips." >&2
  display_usage
  exit 1
fi


if [[ -z "${origin_server_ips[@]}" || -z "${edge_server_ips[@]}" ]]; then
  echo "Missing required options: -o origin_server_ips and -e edge_server_ips." >&2
  display_usage
  exit 1
fi

# Check if Nginx is installed
if ! dpkg-query -W -f='${Status}' nginx | grep -q "installed"; then
  # Install Nginx
  install_nginx
else
  echo "Nginx is already installed. Skipping installation."
fi


# Check if a domain name is provided
if [[ -n "$domain" && -n "$email" ]]; then
  # Install Certbot and SSL certificate
  install_certbot
  install_ssl $domain $email
  ssl_enabled=true

  # Add crontab job for SSL renewal if it doesn't exist
  add_crontab_job "0 0 */80 * * certbot renew --nginx >/dev/null 2>&1"
else
  echo "No domain name and email address specified. Skipping SSL certificate installation."
fi

# Update Nginx configuration
update_nginx_config

# Copy updated Nginx configuration to system's nginx.conf path
sudo cp "nginx.conf" "/etc/nginx/nginx.conf"

# Restart Nginx
restart_nginx

echo "Nginx installation and configuration complete."
