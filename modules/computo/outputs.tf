output "instance_id" {
  description = "ID de la instancia EC2"
  value       = aws_instance.this.id
}

output "instance_ip" {
  description = "IP pública de la instancia EC2"
  value       = aws_instance.this.public_ip
}
