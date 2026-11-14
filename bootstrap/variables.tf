variable "aws_region" {
  description = "Región principal de AWS"
  type        = string
  default     = "us-east-2"
}

variable "state_bucket_name" {
  description = "Nombre globalmente único para el bucket de estado"
  type        = string
}

variable "state_table_name" {
  description = "Tabla DynamoDB para bloquear el estado de Terraform"
  type        = string
  default     = "virtual-binder-terraform-locks"
}

variable "enable_github_oidc" {
  description = "Crear integración OIDC; requiere capacidades avanzadas en la nueva experiencia AWS"
  type        = bool
  default     = false
}
