variable "project_id" {
  description = "ID del proyecto de Google Cloud"
  type        = string
}

variable "region" {
  description = "Región principal de los recursos"
  type        = string
  default     = "us-central1"
}

variable "api_image" {
  description = "Digest inmutable de la imagen de la API"
  type        = string
}

variable "github_actions_service_account" {
  description = "Cuenta de servicio creada por bootstrap para GitHub Actions"
  type        = string
}

variable "alert_email" {
  description = "Correo que recibe alertas operativas y de presupuesto"
  type        = string
}

variable "billing_account" {
  description = "Cuenta de facturación para el presupuesto; vacío deshabilita el presupuesto"
  type        = string
  default     = ""
}

variable "budget_amount_usd" {
  description = "Presupuesto mensual de referencia en USD"
  type        = number
  default     = 100
}

variable "api_min_instances" {
  description = "Instancias mínimas de Cloud Run; usar 0 para minimizar costes"
  type        = number
  default     = 1

  validation {
    condition     = var.api_min_instances >= 0 && var.api_min_instances <= 2
    error_message = "api_min_instances debe estar entre 0 y 2."
  }
}

variable "api_max_instances" {
  description = "Límite de instancias de Cloud Run"
  type        = number
  default     = 2

  validation {
    condition     = var.api_max_instances >= 1 && var.api_max_instances <= 10
    error_message = "api_max_instances debe estar entre 1 y 10."
  }
}
