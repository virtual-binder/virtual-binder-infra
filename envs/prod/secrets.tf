locals {
  secret_ids = toset([
    "database-url",
    "mercadopago-access-token",
    "mercadopago-webhook-secret",
  ])
}

resource "google_secret_manager_secret" "api" {
  for_each = local.secret_ids

  secret_id = each.value

  replication {
    auto {}
  }

  depends_on = [google_project_service.services]
}

resource "google_secret_manager_secret_iam_member" "api_access" {
  for_each = google_secret_manager_secret.api

  secret_id = each.value.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}
