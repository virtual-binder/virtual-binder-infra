data "google_project" "current" {
  project_id = var.project_id
}

resource "google_monitoring_notification_channel" "email" {
  display_name = "Virtual Binder · operaciones"
  type         = "email"

  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_alert_policy" "api_5xx" {
  display_name = "Virtual Binder · errores 5xx de la API"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Errores 5xx sostenidos"

    condition_threshold {
      filter = join(" AND ", [
        "resource.type = \"cloud_run_revision\"",
        "resource.labels.service_name = \"${google_cloud_run_v2_service.api.name}\"",
        "metric.type = \"run.googleapis.com/request_count\"",
        "metric.labels.response_code_class = \"5xx\"",
      ])
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.service_name"]
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}

resource "google_monitoring_uptime_check_config" "api" {
  display_name = "Virtual Binder · salud de la API"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path         = "/salud"
    port         = 443
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = trimprefix(google_cloud_run_v2_service.api.uri, "https://")
    }
  }
}

resource "google_monitoring_alert_policy" "api_unavailable" {
  display_name = "Virtual Binder · API no disponible"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Fallos del chequeo de salud"

    condition_threshold {
      filter = join(" AND ", [
        "resource.type = \"uptime_url\"",
        "metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\"",
        "metric.labels.check_id = \"${google_monitoring_uptime_check_config.api.uptime_check_id}\"",
      ])
      comparison      = "COMPARISON_LT"
      threshold_value = 1
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_FRACTION_TRUE"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]
}

resource "google_billing_budget" "monthly" {
  count = var.billing_account == "" ? 0 : 1

  billing_account = var.billing_account
  display_name    = "Virtual Binder · presupuesto mensual"

  amount {
    specified_amount {
      currency_code = "USD"
      units         = tostring(var.budget_amount_usd)
    }
  }

  budget_filter {
    projects               = ["projects/${data.google_project.current.number}"]
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
  }

  dynamic "threshold_rules" {
    for_each = [0.25, 0.50, 0.75, 0.90]
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  all_updates_rule {
    monitoring_notification_channels = [google_monitoring_notification_channel.email.id]
    disable_default_iam_recipients   = false
  }

  depends_on = [google_project_service.services]
}
