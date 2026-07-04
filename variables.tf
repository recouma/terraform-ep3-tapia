variable "aws_region" {
  description = "Región de AWS donde se desplegará la infraestructura"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nombre del proyecto, usado como prefijo en todos los recursos"
  type        = string
  default     = "AUY1105-proyecto2"
}

variable "vpc_cidr" {
  description = "Bloque CIDR de la VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "public_subnets" {
  description = "Lista de subnets públicas con su CIDR y zona de disponibilidad"
  type = list(object({
    cidr = string
    az   = string
  }))
  default = [
    { cidr = "10.1.1.0/24", az = "us-east-1a" }
  ]
}


variable "instance_type" {
  description = "Tipo de instancia EC2"
  type        = string
  default     = "t2.micro"
}

variable "bucket_name" {
  description = "Nombre del bucket S3 (globalmente único)"
  type        = string
  default     = "auy1105-ep3-tapia-datos"
}
