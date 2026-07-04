# --- Redes ---
output "vpc_id" {
  description = "ID de la VPC creada"
  value       = module.red.vpc_id
}

output "subnet_ids" {
  description = "IDs de las subnets públicas"
  value       = module.red.subnet_ids
}


# --- Cómputo ---
output "instance_id" {
  description = "ID de la instancia EC2"
  value       = module.computo.instance_id
}

output "instance_ip" {
  description = "IP pública de la instancia EC2"
  value       = module.computo.instance_ip
}

# --- Almacenamiento ---
output "bucket_name" {
  description = "Nombre del bucket S3"
  value       = module.almacenamiento.bucket_name
}

output "bucket_arn" {
  description = "ARN del bucket S3"
  value       = module.almacenamiento.bucket_arn
}
