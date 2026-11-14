variable "aws_region" {
  description = "Región principal de AWS"
  type        = string
  default     = "us-east-1"
}

variable "api_image" {
  description = "Digest inmutable de la imagen de la API en ECR"
  type        = string
}

variable "cors_origins" {
  description = "Orígenes permitidos por la API, separados por comas"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Correo que recibe alertas operativas y de presupuesto"
  type        = string
}

variable "budget_amount_usd" {
  description = "Presupuesto mensual de referencia en USD"
  type        = number
  default     = 100
}

variable "api_min_instances" {
  description = "Instancias mínimas de App Runner; pausa el servicio para detener el coste"
  type        = number
  default     = 1

  validation {
    condition     = var.api_min_instances >= 1 && var.api_min_instances <= 2
    error_message = "App Runner requiere al menos una instancia mientras está activo."
  }
}

variable "api_max_instances" {
  description = "Límite de instancias de App Runner"
  type        = number
  default     = 2

  validation {
    condition     = var.api_max_instances >= 1 && var.api_max_instances <= 10
    error_message = "api_max_instances debe estar entre 1 y 10."
  }
}
