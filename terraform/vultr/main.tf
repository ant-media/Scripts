#resource "vultr_instance" "enterprise" {
#    plan = var.vultr_instance
#    region = var.vultr_region
#    os_id = 2284
#    label = var.resource_group_name_community
#}

resource "vultr_ssh_key" "key" {
  name       = "vultr-ssh-key"
  ssh_key    = file(var.publickeypath) 
}

resource "vultr_instance" "community" {
    plan = var.vultr_instance
    region = var.vultr_region
    os_id = 2284
    label = var.resource_group_name_community
    ssh_key_ids       = [vultr_ssh_key.key.id]
}


resource "null_resource" "ams-marketplace-setup_community" {
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.user
      host        = vultr_instance.community.main_ip  
      private_key = file(var.privatekeypath)
    }
    inline = [
      "sudo sed -i 's/#\\$nrconf{kernelhints} = -1;/\\$nrconf{kernelhints} = -1;/g'  /etc/needrestart/needrestart.conf",
      "echo 'NEEDRESTART_SUSPEND=1' >> /etc/environment",
      "sudo source /etc/environment",
      "while sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do sleep 1; done",
      "while sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do sleep 1; done",
      "sudo apt-get update -y",
      "sudo apt-get dist-upgrade -y",
      "wget https://raw.githubusercontent.com/ant-media/Scripts/master/install_ant-media-server.sh",
      "curl -L -o ant-media-server-community.zip https://github.com/ant-media/Ant-Media-Server/releases/download/ams-v${var.ams_version}/ant-media-server-community-${var.ams_version}.zip",
      "sudo bash ./install_ant-media-server.sh -i ant-media-server-community.zip",
      "sudo sed -i 's/server.marketplace=.*/server.marketplace=azure/g' /usr/local/antmedia/conf/red5.properties",
      "sudo systemctl stop antmedia",
      "sudo rm -rf /usr/local/antmedia/conf/instanceId",
      "sudo rm -rf /usr/local/antmedia/*.db.* && sudo rm -rf /usr/local/antmedia/*.db",
      "sudo rm -rf /root/*.zip && sudo rm -rf /root/install*",
      "sudo rm -rf /root/.ssh",
      "history -c",
      "sudo shutdown -h now",
 
    ]
  }
  depends_on = [
    vultr_instance.community           
  ]
  
}

resource "vultr_firewall_group" "my_firewall_grp" {
    description = "Firewall"
}
resource "vultr_firewall_rule" "allow_http" {
    firewall_group_id = vultr_firewall_group.my_firewall_grp.id
    protocol = "tcp"
    ip_type = "v4"
    subnet = "0.0.0.0"
    subnet_size = 0
    port = "5080"
}
resource "vultr_firewall_rule" "allow_https" {
    firewall_group_id = vultr_firewall_group.my_firewall_grp.id
    protocol = "tcp"
    ip_type = "v4"
    subnet = "0.0.0.0"
    subnet_size = 0
    port = "5443"
}
resource "vultr_firewall_rule" "allow_ssh" {
    firewall_group_id = vultr_firewall_group.my_firewall_grp.id
    protocol = "tcp"
    ip_type = "v4"
    subnet = "0.0.0.0"
    subnet_size = 0
    port = "22"
}

resource "vultr_snapshot" "snapshot" {
  instance_id = resource.vultr_instance.community.id


  timeouts {
    create = "60m"
  }
  depends_on = [
    null_resource.ams-marketplace-setup_community          
  ]

}

output "ipv4_address" {
  value = vultr_instance.community.main_ip
}