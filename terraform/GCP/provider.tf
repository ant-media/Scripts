provider "google" {
#  credentials = file("antmedia-dev.json")
  project = var.project
  region  = var.region
  zone = var.zone
}