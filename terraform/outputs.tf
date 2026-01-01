# Output Values

output "cluster_name" {
  description = "GKE Cluster Name"
  value       = google_container_cluster.autopilot.name
}

output "cluster_endpoint" {
  description = "GKE Cluster Endpoint"
  value       = google_container_cluster.autopilot.endpoint
  sensitive   = true
}

output "cluster_location" {
  description = "GKE Cluster Location"
  value       = google_container_cluster.autopilot.location
}

output "app_data_bucket" {
  description = "Application Data Bucket Name"
  value       = google_storage_bucket.app_data.name
}

output "app_data_bucket_url" {
  description = "Application Data Bucket URL"
  value       = google_storage_bucket.app_data.url
}
