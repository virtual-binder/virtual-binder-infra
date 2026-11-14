variable "aws_region" {
  description = "Región principal de AWS"
  type        = string
  default     = "us-east-2"
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
