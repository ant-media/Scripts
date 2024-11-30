variable "do_token" {
  type = string
}

variable "do_droplet_enable" {
  default = true
}

variable "do_region" {
  default = "fra1"
}

variable "do_instance_type" {
  default = "c-2"
}

variable "do_image" {
  default = "ubuntu-22-04-x64"
}

variable "zip_file_id" {
  description = "Google drive ID"
  type        = string
  #default = "xxxxxxx" 
}

