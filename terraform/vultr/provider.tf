terraform {
  required_providers {
    vultr = {
      source = "vultr/vultr"
      version = "2.23.1"
    }
  }
}

# Configure the Vultr Provider
provider "vultr" {
  api_key = var.vultr_token
  rate_limit = 100
  retry_limit = 3
}