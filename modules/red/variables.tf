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

variable "sg_ingress_rules" {
  description = "Reglas de ingreso para el security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
}

variable "common_tags" {
  description = "Tags comunes para todos los recursos"
  type        = map(string)
  default     = {}
}
