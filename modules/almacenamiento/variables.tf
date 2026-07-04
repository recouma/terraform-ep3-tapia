variable "bucket_name" {
  description = "Nombre del bucket S3"
  type        = string
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "common_tags" {
  description = "Tags comunes"
  type        = map(string)
  default     = {}
}
