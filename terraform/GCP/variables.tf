variable "project" {
  type        = string
  description = "The project ID to deploy to"
  default     = "antmedia-dev"
}

variable "public_project" {
  type        = string
  description = "The project ID to deploy to"
  default     = "antmedia-public-385620"
}


variable "region" {
  type        = string
  description = "The region to deploy to"
  default     = "us-central1"

}

variable "zone" {
  type        = string
  description = "The zone to deploy to"
  default     = "us-central1-a"
}

variable "machine_type" {
  type        = string
  description = "The machine type to deploy to"
  default     = "e2-medium"
}

variable "image" {
  type        = string
  description = "The image to deploy to"
  default     = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
}

variable "ams_version" {
  type        = string
  description = "Version number of AMS"
}

variable "publickeypath" {
  type    = string
  default = "./ssh/id_rsa.pub"
}

variable "privatekeypath" {
  type    = string
  default = "./ssh/id_rsa"
}

variable "user" {
  type    = string
  default = "root"

}

variable "zip_file_id" {
  description = "Google drive ID"
  type        = string
}
