output "api_url" {
  value = google_cloud_run_v2_service.api.uri
}

output "artifact_registry_repository" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${data.google_artifact_registry_repository.containers.repository_id}"
}

output "images_bucket" {
  value = google_storage_bucket.card_images.name
}

output "api_service_account" {
  value = google_service_account.api.email
}
