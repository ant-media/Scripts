resource "digitalocean_ssh_key" "default" {
  name       = "Terraform_Temp"
  public_key = file("./ssh/id_rsa.pub")
}

resource "digitalocean_droplet" "enterprise" {
  count  = var.do_droplet_enable ? 1 : 0
  image  = var.do_image
  name   = "ams-server-enterprise"
  region = var.do_region
  size   = var.do_instance_type
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]

  provisioner "file" {
    source = "init.sh"
    destination = "/tmp/init.sh"
    
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("./ssh/id_rsa")
      host        = digitalocean_droplet.enterprise[count.index].ipv4_address
    }

  }


  provisioner "remote-exec" {
    inline = [
      "sudo rm /var/lib/dpkg/lock",
      "sudo rm /var/lib/apt/lists",
      "wget https://raw.githubusercontent.com/ant-media/Scripts/master/install_ant-media-server.sh",
      "curl -L 'https://drive.usercontent.google.com/download?id=${var.zip_file_id}&export=download&confirm=t' -o 'ams.zip'",
      "bash install_ant-media-server.sh -i ams.zip",
      "bash /tmp/init.sh",
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("./ssh/id_rsa")
      host        = digitalocean_droplet.enterprise[count.index].ipv4_address
    }
  }
}

resource "null_resource" "poweroff-enterprise" {
  count = length(digitalocean_droplet.enterprise)  # Tüm droplet'ler için döngü

  provisioner "local-exec" {
    command = <<EOT
      curl -X POST -H "Content-Type: application/json" \
           -H "Authorization: Bearer ${var.do_token}" \
           "https://api.digitalocean.com/v2/droplets/${digitalocean_droplet.enterprise[count.index].id}/actions" \
           -d '{"type":"power_off"}'
    EOT
  }

  depends_on = [digitalocean_droplet.enterprise]
}


resource "digitalocean_droplet_snapshot" "ams-enterprise-snapshot" {
  count = var.do_droplet_enable ? 1 : 0
  droplet_id = digitalocean_droplet.enterprise[count.index].id
  name       = "ams-enterprise-snapshot-01"
}

resource "digitalocean_droplet" "community" {
  count = var.do_droplet_enable ? 1 : 0
  image  = var.do_image
  name   = "ams-server-community"
  region = var.do_region
  size   = var.do_instance_type
  ssh_keys = [digitalocean_ssh_key.default.fingerprint]

  provisioner "file" {
    source = "init.sh"
    destination = "/tmp/init.sh"
    
    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("./ssh/id_rsa")
      host        = digitalocean_droplet.community[count.index].ipv4_address
    }

  }


  provisioner "remote-exec" {
    inline = [
      "sudo apt-get purge droplet-agent -y",
      "wget https://raw.githubusercontent.com/ant-media/Scripts/master/install_ant-media-server.sh",
      "bash install_ant-media-server.sh",
      "bash /tmp/init.sh",
    ]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file("./ssh/id_rsa")
      host        = digitalocean_droplet.community[count.index].ipv4_address
    }
  }
}

resource "null_resource" "poweroff-community" {
  count = length(digitalocean_droplet.community)  # Tüm droplet'ler için döngü

  provisioner "local-exec" {
    command = <<EOT
      curl -X POST -H "Content-Type: application/json" \
           -H "Authorization: Bearer ${var.do_token}" \
           "https://api.digitalocean.com/v2/droplets/${digitalocean_droplet.community[count.index].id}/actions" \
           -d '{"type":"power_off"}'
    EOT
  }

  depends_on = [digitalocean_droplet.community]
}

resource "digitalocean_droplet_snapshot" "ams-community-snapshot" {
  count = var.do_droplet_enable ? 1 : 0
  droplet_id = digitalocean_droplet.community[count.index].id
  name       = "ams-community-snapshot-01"
}
