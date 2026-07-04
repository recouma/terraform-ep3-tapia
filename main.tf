# =============================================================================
# AUY1105 — Evaluación Parcial 3
# Gestión Avanzada de Recursos de Terraform
# -----------------------------------------------------------------------------
# Estudiante: Daniel Tapia Sobarzo — @recouma
# Orquesta los módulos locales de redes, cómputo y almacenamiento.
# =============================================================================

terraform {
  required_version = ">= 1.2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# =============================================================================
# Módulo de Redes
# =============================================================================
module "red" {
  source = "./modules/red"

  vpc_cidr         = var.vpc_cidr
  project_name     = var.project_name
  public_subnets   = var.public_subnets
  common_tags      = local.common_tags
}

# =============================================================================
# Módulo de Cómputo
# =============================================================================
module "computo" {
  source = "./modules/computo"

  instance_type      = var.instance_type
  subnet_id          = module.red.subnet_ids[0]
  security_group_ids = ["sg-0140f2ef1215b954d"]
  project_name       = var.project_name
  common_tags        = local.common_tags
}

# =============================================================================
# Módulo de Almacenamiento
# =============================================================================
module "almacenamiento" {
  source = "./modules/almacenamiento"

  bucket_name  = var.bucket_name
  project_name = var.project_name
  common_tags  = local.common_tags
}

locals {
  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
  }
}
