variable "project_id" {
  description = "ID del proyecto de Google Cloud"
  type        = string
}

variable "region" {
  description = "Región de Workload Identity"
  type        = string
  default     = "us-central1"
}

variable "state_bucket_name" {
  description = "Nombre globalmente único para el bucket de estado"
  type        = string
}

variable "state_bucket_location" {
  description = "Ubicación del bucket de estado"
  type        = string
  default     = "US"
}
