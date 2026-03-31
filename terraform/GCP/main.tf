resource "google_compute_instance" "ams-marketplace" {

  name         = "ams-marketplace-${var.ams_version}"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["allow-all"]
  boot_disk {
    initialize_params {
      image = var.image
    }
  }
  network_interface {
    network = "default"
    access_config {

    }
  }

  metadata = {
      ssh-keys = "${var.user}:${file(var.publickeypath)}"
  }
}

resource "google_compute_firewall" "ams-allow_port_5080" {
  name    = "ams-allow-port-5080"
  network = "default"  

  allow {
    protocol = "tcp"
    ports    = ["5080"]
  }

  source_ranges = ["0.0.0.0/0"] 
}

resource "null_resource" "ams-marketplace-setup" {
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.user
      host        = google_compute_instance.ams-marketplace.network_interface[0].access_config[0].nat_ip
      private_key = file(var.privatekeypath)
    }
    inline = [
      "sudo sed -i 's/#\\$nrconf{kernelhints} = -1;/\\$nrconf{kernelhints} = -1;/g'  /etc/needrestart/needrestart.conf",
      "echo 'NEEDRESTART_SUSPEND=1' >> /etc/environment",
      "sudo source /etc/environment",
      "sudo apt-get update",
      "sudo apt-get dist-upgrade -y",
      "wget https://raw.githubusercontent.com/ant-media/Scripts/master/install_ant-media-server.sh",
      "curl -L 'https://drive.usercontent.google.com/download?id=${var.zip_file_id}&export=download&confirm=t' -o 'ams.zip'",
      "sudo bash ./install_ant-media-server.sh -i ams.zip",
      "sudo sed -i 's/server.marketplace=.*/server.marketplace=gcp/g' /usr/local/antmedia/conf/red5.properties",
      "sudo systemctl stop antmedia",
      "sudo rm -rf /usr/local/antmedia/conf/instanceId",
      "sudo rm -rf /usr/local/antmedia/*.db.* && sudo rm -rf /usr/local/antmedia/*.db",
      "sudo rm -rf /root/*.zip && sudo rm -rf /root/install*",
      "sudo rm -rf /root/.ssh",
    ]
  }
}

resource "null_resource" "stop_instance" {
  provisioner "local-exec" {
    command = "gcloud compute instances stop ams-marketplace-${var.ams_version} --project=${var.project} --zone=${var.zone}"
  }
  depends_on = [null_resource.ams-marketplace-setup]
}


resource "google_compute_image" "ams_marketplace_image" {
  name         = "ams-marketplace-${var.ams_version}"
  source_disk  = "projects/antmedia-dev/zones/${var.zone}/disks/ams-marketplace-${var.ams_version}"
  licenses     = ["projects/${var.public_project}/global/licenses/cloud-marketplace-211adc9aa41170ec-df1ebeb69c0ba664"]
  description  = "AMS-ams-marketplace-${var.ams_version}"
  project      = "${var.public_project}"
  depends_on = [null_resource.stop_instance]
}


resource "google_compute_image_iam_binding" "iam" {
  image  = "projects/${var.public_project}/global/images/ams-marketplace-${var.ams_version}"
  role   = "roles/compute.imageUser"
  
  members = [
    "allAuthenticatedUsers"
  ]
  depends_on = [google_compute_image.ams_marketplace_image]
}
