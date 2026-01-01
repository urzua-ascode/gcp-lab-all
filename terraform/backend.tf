# Terraform Configuration Example
# This is a template - customize according to your needs

terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Backend configuration - will be created by setup.sh
  backend "gcs" {
    # bucket  = "YOUR_PROJECT_ID-terraform-state"  # Uncomment and set your bucket name
    # prefix  = "terraform/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
