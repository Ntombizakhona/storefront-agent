# Terraform: a small GCE VM running WordPress + WooCommerce via docker-compose.
# Usage:
#   cd deploy/gce
#   terraform init
#   terraform apply -var="project_id=YOUR_PROJECT"
# Output `store_url` is your WP_API_URL.

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

variable "project_id" {
  type        = string
  description = "Google Cloud project ID."
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "zone" {
  type    = string
  default = "us-central1-a"
}

variable "machine_type" {
  type    = string
  default = "e2-small" # 2 vCPU burst, 2 GB RAM - enough for a demo store
}

variable "allowed_ingress_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "Restrict to your IP (e.g. 1.2.3.4/32) for a safer demo."
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "store" {
  name                    = "storefront-net"
  auto_create_subnetworks = true
}

resource "google_compute_firewall" "http" {
  name    = "storefront-allow-http"
  network = google_compute_network.store.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = [var.allowed_ingress_cidr]
  target_tags   = ["storefront"]
}

resource "google_compute_instance" "store" {
  name         = "storefront-woocommerce"
  machine_type = var.machine_type
  tags         = ["storefront"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
    }
  }

  network_interface {
    network = google_compute_network.store.name
    access_config {} # ephemeral public IP
  }

  metadata_startup_script = file("${path.module}/startup-script.sh")
}

output "store_url" {
  value       = "http://${google_compute_instance.store.network_interface[0].access_config[0].nat_ip}"
  description = "Set this as WP_API_URL once WordPress finishes booting (~2-3 min)."
}
