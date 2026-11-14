output "state_bucket_name" {
  value = google_storage_bucket.terraform_state.name
}

output "github_actions_service_account" {
  value = google_service_account.github_actions.email
}

output "api_github_actions_service_account" {
  value = google_service_account.api_github_actions.email
}

output "workload_identity_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "artifact_registry_repository" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.containers.repository_id}"
}
