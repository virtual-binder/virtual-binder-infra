variable "aws_region" {
  description = "Región principal de AWS"
  type        = string
  default     = "us-east-1"
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
