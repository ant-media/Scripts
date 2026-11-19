variable "resource_group_location" {
  default     = "North Europe"
  description = "Location of the resource group."
}

variable "resource_group_name_enterprise" {
  default     = "enterprise"
  description = "Name"
  type        = string
}

variable "rg_name" {
  description = "Enter the Azure Resource Group Name"
  type        = string
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
  default = "ubuntu"

}

variable "ams_version" {
  type        = string
  description = "AMS Version"
}

variable "zip_file_id" {
  description = "Google drive ID"
  type        = string
}
