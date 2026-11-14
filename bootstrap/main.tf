locals {
  bootstrap_apis = toset([
    "artifactregistry.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "serviceusage.googleapis.com",
    "storage.googleapis.com",
  ])
}

resource "google_project_service" "bootstrap" {
  for_each = local.bootstrap_apis

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_storage_bucket" "terraform_state" {
  name                        = var.state_bucket_name
  location                    = var.state_bucket_location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.bootstrap]
}

resource "google_service_account" "github_actions" {
  account_id   = "virtual-binder-github"
  display_name = "Virtual Binder · GitHub Actions"
  description  = "Identidad usada por los workflows de infraestructura"

  depends_on = [google_project_service.bootstrap]
}

resource "google_service_account" "api_github_actions" {
  account_id   = "virtual-binder-api-ci"
  display_name = "Virtual Binder · API CI"
  description  = "Identidad usada únicamente para publicar imágenes de la API"

  depends_on = [google_project_service.bootstrap]
}

resource "google_artifact_registry_repository" "containers" {
  project       = var.project_id
  location      = var.region
  repository_id = "virtual-binder"
  format        = "DOCKER"
  description   = "Imágenes inmutables de los servicios de Virtual Binder"

  depends_on = [google_project_service.bootstrap]
}

resource "google_artifact_registry_repository_iam_member" "api_ci_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.containers.location
  repository = google_artifact_registry_repository.containers.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.api_github_actions.email}"
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "virtual-binder-github"
  display_name              = "Virtual Binder · GitHub"
  description               = "Autenticación OIDC para GitHub Actions"

  depends_on = [google_project_service.bootstrap]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions"
  display_name                       = "GitHub Actions"
  attribute_condition                = "assertion.repository_owner == 'virtual-binder'"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
    "attribute.ref"              = "assertion.ref"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "infra_workload_identity" {
  service_account_id = google_service_account.github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/virtual-binder/virtual-binder-infra"
}

resource "google_service_account_iam_member" "api_workload_identity" {
  service_account_id = google_service_account.api_github_actions.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/virtual-binder/virtual-binder-api"
}
