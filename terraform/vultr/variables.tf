variable "vultr_token" {
  type = string
}

variable "vultr_region" {
    type = string
    default = "fra"
} 

variable "vultr_instance" {
    type = string
    default = "vc2-2c-4gb"
}

variable "resource_group_name_enterprise" {
  default     = "enterprise"
  description = "Name"
}


variable "resource_group_name_community" {
  default     = "community"
  description = "Name"
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

variable "ams_version" {
  type        = string
  description = "AMS Version"
}

variable "zip_file_id" {
  description = "Google drive ID"
  type        = string
}