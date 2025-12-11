resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = "community" // or "enterprise" based on your needs
}

resource "azurerm_virtual_network" "antmedia-marketplace" {
  name                = "antmedia-marketplace-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "antmedia-marketplace" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.antmedia-marketplace.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "antmedia-marketplace" {
  name                = "antmedia-marketplace-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.antmedia-marketplace.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.antmedia-marketplace.id
  }
}

resource "azurerm_linux_virtual_machine" "antmedia-marketplace" {
  name                = "antmedia-marketplace-machine"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_F2s_v2"
  admin_username      = var.user
  network_interface_ids = [
    azurerm_network_interface.antmedia-marketplace.id,
  ]

  admin_ssh_key {
    username   = var.user
    public_key = file(var.publickeypath)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
}


resource "azurerm_public_ip" "antmedia-marketplace" {
  name                = "antmedia-marketplace-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

output "public_ip_address" {
  value = azurerm_public_ip.antmedia-marketplace.ip_address
}

output "ams_version_debug" {
  value = var.ams_version
}

resource "azurerm_network_security_group" "antmedia-marketplace" {
  name                = "antmedia-marketplace-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow-22"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-5080"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5080"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-internet"
    priority                   = 300
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

}

resource "azurerm_network_interface_security_group_association" "antmedia-marketplace" {
  network_interface_id       = azurerm_network_interface.antmedia-marketplace.id
  network_security_group_id = azurerm_network_security_group.antmedia-marketplace.id
}


resource "null_resource" "ams-marketplace-setup_enterprise" {
  count = azurerm_resource_group.rg.name == "enterprise" ? 1 : 0
  depends_on = [
    azurerm_linux_virtual_machine.antmedia-marketplace,  
    azurerm_network_interface.antmedia-marketplace,       
    azurerm_public_ip.antmedia-marketplace                 
  ]
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.user
      host        = azurerm_public_ip.antmedia-marketplace.ip_address
      private_key = file(var.privatekeypath)
    }
    inline = [
      "sudo sed -i 's/#\\$nrconf{kernelhints} = -1;/\\$nrconf{kernelhints} = -1;/g'  /etc/needrestart/needrestart.conf",
      "echo 'NEEDRESTART_SUSPEND=1' >> /etc/environment",
      "source /etc/environment",
      "sudo apt-get update",
      "sudo apt-get dist-upgrade -y",
      "wget https://raw.githubusercontent.com/ant-media/Scripts/master/install_ant-media-server.sh",
      "curl -L 'https://drive.usercontent.google.com/download?id=${var.zip_file_id}&export=download&confirm=t' -o 'ams.zip'",
      "sudo bash ./install_ant-media-server.sh -i ams.zip",
      "sudo sed -i 's/server.marketplace=.*/server.marketplace=azure/g' /usr/local/antmedia/conf/red5.properties",
      "sudo systemctl stop antmedia",
      "sudo rm -rf /usr/local/antmedia/conf/instanceId",
      "sudo rm -rf /usr/local/antmedia/*.db.* && sudo rm -rf /usr/local/antmedia/*.db",
      "sudo rm -rf /root/*.zip && sudo rm -rf /root/install*",
      "sudo rm -rf /root/.ssh",
      "sudo waagent -deprovision+user -force",
    ]
  }
}

resource "null_resource" "ams-marketplace-setup_community" {
  count = azurerm_resource_group.rg.name == "community" ? 1 : 0
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.user
      host        = azurerm_public_ip.antmedia-marketplace.ip_address  
      private_key = file(var.privatekeypath)
    }
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      "echo 'APT::Get::Assume-Yes \"true\";' | sudo tee /etc/apt/apt.conf.d/90assumeyes",
      "echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections",
      "echo 'systemd restart services' | sudo tee /etc/needrestart/conf.d/override.conf",
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
      "sudo waagent -deprovision+user -force",
    ]
  }
  depends_on = [
    azurerm_linux_virtual_machine.antmedia-marketplace,  
    azurerm_network_interface.antmedia-marketplace,       
    azurerm_public_ip.antmedia-marketplace                 
  ]

}


resource "null_resource" "stop_and_generalize_vm" {
  provisioner "local-exec" {
    command = <<-EOT
      echo "VM'i durduruyor..."
      az vm deallocate --name ${azurerm_linux_virtual_machine.antmedia-marketplace.name} --resource-group ${azurerm_resource_group.rg.name}
      
      echo "VM'in durmasını bekliyor..."
      az vm wait --name ${azurerm_linux_virtual_machine.antmedia-marketplace.name} --resource-group ${azurerm_resource_group.rg.name} --deallocated
      
      echo "VM'i generalize ediyor..."
      az vm generalize --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_linux_virtual_machine.antmedia-marketplace.name}
      
      echo "Generalize durumunu kontrol ediyor..."
      while true; do
        STATUS=$(az vm get-instance-view --name ${azurerm_linux_virtual_machine.antmedia-marketplace.name} --resource-group ${azurerm_resource_group.rg.name} --query "instanceView.statuses[?code=='OSState/generalized']" --output tsv)
        if [ ! -z "$STATUS" ]; then
          echo "VM başarıyla generalize edildi."
          break
        fi
        echo "Generalize işlemi devam ediyor, bekleniyor..."
        sleep 10
      done
    EOT
  }

  depends_on = [
    azurerm_linux_virtual_machine.antmedia-marketplace,
    azurerm_network_interface.antmedia-marketplace,
    azurerm_public_ip.antmedia-marketplace,
    null_resource.ams-marketplace-setup_community,
    null_resource.ams-marketplace-setup_enterprise
  ]
}

resource "azurerm_image" "antmedia-marketplace" {
  name                = "antmedia-marketplace-image-${azurerm_resource_group.rg.name}-${var.ams_version}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  hyper_v_generation  = "V2" 

  source_virtual_machine_id = azurerm_linux_virtual_machine.antmedia-marketplace.id

  depends_on = [
    null_resource.stop_and_generalize_vm,
    null_resource.ams-marketplace-setup_community,
    null_resource.ams-marketplace-setup_enterprise
  ]
}

# Shared Image Gallery
resource "azurerm_shared_image_gallery" "antmedia-marketplace" {
  name                = "${azurerm_resource_group.rg.name}_image_gallery"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  description         = "Shared images and things."

  tags = {
    Marketplace = "Ant Media Server"
  }
  
  depends_on = [azurerm_image.antmedia-marketplace]
}

# Shared Image Definition
resource "azurerm_shared_image" "antmedia-marketplace" {
  name                = var.ams_version
  gallery_name        = azurerm_shared_image_gallery.antmedia-marketplace.name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  hyper_v_generation  = "V2"

  identifier {
    publisher = "antmedia"
    offer     = "Ubuntu"
    sku       = "Ubuntu"
  }
  
  depends_on = [azurerm_shared_image_gallery.antmedia-marketplace]
}

# Shared Image Version - Managed Image'i kullan
resource "azurerm_shared_image_version" "antmedia-marketplace" {
  name                = var.ams_version
  gallery_name        = azurerm_shared_image_gallery.antmedia-marketplace.name
  image_name          = azurerm_shared_image.antmedia-marketplace.name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  
  # VM ID yerine Managed Image ID kullan
  managed_image_id    = azurerm_image.antmedia-marketplace.id

  target_region {
    name                   = azurerm_resource_group.rg.location
    regional_replica_count = 5
    storage_account_type   = "Standard_LRS"
  }
  
  depends_on = [
    azurerm_shared_image.antmedia-marketplace,
    azurerm_image.antmedia-marketplace
  ]
}

