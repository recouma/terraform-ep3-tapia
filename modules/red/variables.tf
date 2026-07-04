variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC"
  type        = string
}

variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}

variable "public_subnets" {
  description = "Lista de subnets públicas"
  type = list(object({
    cidr = string
    az   = string
  }))
}


variable "common_tags" {
  description = "Tags comunes para todos los recursos"
  type        = map(string)
  default     = {}
}
