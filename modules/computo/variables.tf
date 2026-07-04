variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
}

variable "subnet_id" {
  description = "ID de la subnet donde lanzar la instancia"
  type        = string
}

variable "security_group_ids" {
  description = "IDs de los security groups"
  type        = list(string)
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
