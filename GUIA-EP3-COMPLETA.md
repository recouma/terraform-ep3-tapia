# EP3 — Guía Completa Paso a Paso
## AUY1105 — Infraestructura como Código II
### Daniel Tapia Sobarzo — @recouma

---

## Prerequisitos

1. Tener AWS CLI configurado con credenciales del Learner Lab
2. Tener Terraform instalado (v1.2+)
3. Clonar este repositorio en tu WSL o PC del lab

```bash
# Verificar conexión al lab
aws sts get-caller-identity
```

---

## Paso 0 — Desplegar la infraestructura base

```bash
cd ep3-terraform
terraform init
terraform apply -auto-approve
terraform output
terraform state list
```

Resultado esperado: `11 added` (11 recursos + 1 data source), luego `terraform plan` → `No changes`.

Anota los IDs que entrega `terraform output`:
- `vpc_id`
- `subnet_ids`
- `security_group_id`
- `instance_id`
- `bucket_name`

Para anotar TODOS los IDs necesarios para el import:

```bash
terraform state show module.red.aws_vpc.this | grep -m1 'id '
terraform state show module.red.aws_subnet.public[0] | grep -m1 'id '
terraform state show module.red.aws_internet_gateway.this | grep -m1 'id '
terraform state show module.red.aws_route_table.public | grep -m1 'id '
terraform state show module.red.aws_security_group.this | grep -m1 'id '
terraform state show module.computo.aws_instance.this | grep -m1 'id '
terraform state show module.almacenamiento.aws_s3_bucket.this | grep -m1 'bucket '
```

**GUARDA ESTOS IDS EN UN ARCHIVO. Los necesitas para el Escenario 1.**

---

## Escenario 1 — Recuperación del estado (import)

### 1.1 Simular la pérdida del estado

```bash
# Hacer backup y eliminar el estado
mv terraform.tfstate terraform.tfstate.BACKUP

# Verificar que Terraform "olvidó" todo
terraform plan 2>&1 | tee evidencias/ep3/esc1-plan-sin-estado.txt
```

Resultado esperado: `Plan: 11 to add` (quiere recrear todo).

### 1.2 Importar cada recurso (reemplaza con TUS IDs)

```bash
# Redes
terraform import 'module.red.aws_vpc.this' VPC_ID
terraform import 'module.red.aws_subnet.public[0]' SUBNET_ID
terraform import 'module.red.aws_internet_gateway.this' IGW_ID
terraform import 'module.red.aws_route_table.public' RTB_ID
terraform import 'module.red.aws_security_group.this' SG_ID
terraform import 'module.red.aws_route_table_association.public[0]' SUBNET_ID/RTB_ID

# Cómputo
terraform import 'module.computo.aws_instance.this' EC2_ID

# Almacenamiento (usa el NOMBRE del bucket, no un ID)
terraform import 'module.almacenamiento.aws_s3_bucket.this' BUCKET_NAME
terraform import 'module.almacenamiento.aws_s3_bucket_versioning.this' BUCKET_NAME
terraform import 'module.almacenamiento.aws_s3_bucket_server_side_encryption_configuration.this' BUCKET_NAME
terraform import 'module.almacenamiento.aws_s3_bucket_public_access_block.this' BUCKET_NAME
```

> **Notas:**
> - `aws_route_table_association` usa ID compuesto: `SUBNET_ID/RTB_ID`
> - El data source `aws_ami` NO se importa, se resuelve automáticamente
> - El orden importa: importa la VPC y subnet antes de los recursos que dependen de ellos

### 1.3 Verificar

```bash
terraform state list 2>&1 | tee evidencias/ep3/esc1-state-list.txt
terraform state show 'module.computo.aws_instance.this' 2>&1 | tee evidencias/ep3/esc1-state-show.txt
terraform plan 2>&1 | tee evidencias/ep3/esc1-plan-final.txt
```

Resultado esperado: `No changes. Your infrastructure matches the configuration.`

---

## Escenario 2 — Drift y recreación (refresh + taint)

### Parte A — Detectar y sincronizar drift

**Paso manual en la consola de AWS:**
1. Ve a EC2 → Security Groups
2. Selecciona tu SG
3. Agrega una regla de entrada: Puerto 80, TCP, Origen 0.0.0.0/0

```bash
# Detectar el drift
terraform plan 2>&1 | tee evidencias/ep3/esc2a-plan-drift.txt
```

Resultado: Terraform detecta la regla extra del puerto 80 y quiere eliminarla.

```bash
# Sincronizar estado con la realidad de AWS
terraform apply -refresh-only 2>&1 | tee evidencias/ep3/esc2a-refresh.txt
# Confirma con: yes
```

```bash
# Plan después del refresh — aún muestra diferencia
terraform plan 2>&1 | tee evidencias/ep3/esc2a-plan-post-refresh.txt
```

El plan sigue mostrando diferencia porque el CÓDIGO no tiene la regla del puerto 80, pero el ESTADO ahora sí la tiene (porque sincronizamos con AWS).

```bash
# Aplicar el código como fuente de verdad (elimina la regla manual)
terraform apply 2>&1 | tee evidencias/ep3/esc2a-apply.txt
# Confirma con: yes

# Verificar
terraform plan 2>&1 | tee evidencias/ep3/esc2a-plan-limpio.txt
```

Resultado: `No changes`.

### Parte B — Recreación con taint

```bash
# Marcar la EC2 para recreación
terraform taint 'module.computo.aws_instance.this'

# Ver el impacto
terraform plan 2>&1 | tee evidencias/ep3/esc2b-plan-taint.txt

# Aplicar (destruye y recrea la EC2)
terraform apply 2>&1 | tee evidencias/ep3/esc2b-apply-taint.txt
# Confirma con: yes
```

Resultado: `1 added, 0 changed, 1 destroyed`. La EC2 tiene nuevo ID y nueva IP.

### Parte C — Limpieza con untaint

```bash
# Intentar untaint (ya se consumió al recrear)
terraform untaint 'module.computo.aws_instance.this' 2>&1 | tee evidencias/ep3/esc2c-untaint.txt

# Verificar
terraform plan 2>&1 | tee evidencias/ep3/esc2c-plan-final.txt
```

Resultado: `Resource instance is not tainted` + `No changes`.

---

## Escenario 3 — Eliminación de recurso del estado (state rm)

**Este es el escenario clave. Al usar módulos locales, SÍ podemos lograr `No changes`.**

### 3.1 Estado antes

```bash
terraform state list 2>&1 | tee evidencias/ep3/esc3-state-list-antes.txt
```

El SG (`module.red.aws_security_group.this`) aparece en la lista.

### 3.2 Anotar el SG ID

```bash
terraform output security_group_id
# Anota este valor: sg-XXXXXXXX
```

### 3.3 Sacar el SG del estado

```bash
terraform state rm 'module.red.aws_security_group.this' 2>&1 | tee evidencias/ep3/esc3-state-rm.txt
```

Resultado: `Successfully removed 1 resource instance(s).`

### 3.4 Verificar que salió del estado

```bash
terraform state list 2>&1 | tee evidencias/ep3/esc3-state-list-despues.txt
```

El SG ya no aparece.

### 3.5 Verificar que sigue vivo en AWS

```bash
aws ec2 describe-security-groups --group-ids SG_ID \
  --query "SecurityGroups[0].GroupId" --output text \
  2>&1 | tee evidencias/ep3/esc3-aws-verificar.txt
```

Devuelve el ID del SG → sigue existiendo en AWS.

### 3.6 Eliminar el SG del CÓDIGO (esto es lo que permite el "No changes")

Hay que hacer 3 ediciones:

**A) En `modules/red/main.tf` — eliminar todo el bloque `resource "aws_security_group" "this"`**

Borra desde `# --- Security Group ---` hasta el cierre del recurso `}`.

**B) En `modules/red/outputs.tf` — eliminar el output `security_group_id`**

Borra el bloque:
```hcl
output "security_group_id" {
  ...
}
```

**C) En `main.tf` (raíz) — cambiar la referencia del SG en el módulo de cómputo**

Cambiar:
```hcl
security_group_ids = [module.red.security_group_id]
```
Por el ID hardcodeado del SG que anotaste:
```hcl
security_group_ids = ["sg-XXXXXXXX"]
```

**D) En `outputs.tf` (raíz) — eliminar el output `security_group_id`**

Borra el bloque:
```hcl
output "security_group_id" {
  ...
}
```

**E) En `modules/red/variables.tf` — eliminar la variable `sg_ingress_rules`**

**F) En `main.tf` (raíz) — eliminar el argumento `sg_ingress_rules` del módulo `red`**

Borra la línea:
```hcl
sg_ingress_rules = var.sg_ingress_rules
```

**G) En `variables.tf` (raíz) — eliminar la variable `sg_ingress_rules`**

### 3.7 Validar

```bash
terraform plan 2>&1 | tee evidencias/ep3/esc3-plan-final.txt
```

**Resultado esperado: `No changes. Your infrastructure matches the configuration.`**

El SG sigue vivo en AWS, pero Terraform ya no lo gestiona ni en el código ni en el estado.

### 3.8 Confirmar en AWS una última vez

```bash
aws ec2 describe-security-groups --group-ids SG_ID --output table \
  2>&1 | tee evidencias/ep3/esc3-aws-final.txt
```

---

## Resumen de comandos utilizados

| Comando | Función | Escenario |
|---------|---------|-----------|
| `terraform import` | Asocia un recurso existente con el estado | 1 |
| `terraform state list` | Lista los recursos gestionados | 1, 3 |
| `terraform state show` | Muestra los atributos de un recurso | 1, 2 |
| `terraform apply -refresh-only` | Sincroniza el estado con la realidad | 2 |
| `terraform taint` | Marca un recurso para recreación | 2 |
| `terraform untaint` | Revierte la marca de recreación | 2 |
| `terraform state rm` | Elimina un recurso del estado (sin destruirlo) | 3 |
| `terraform plan` | Compara código vs estado vs realidad | 1, 2, 3 |
| `terraform apply` | Aplica los cambios a la infraestructura | 2 |

---

## Notas de buenas prácticas

- `terraform refresh` está **deprecado** → usar `terraform apply -refresh-only`
- `terraform taint` está **deprecado** → el moderno es `terraform apply -replace='<dirección>'`
- El `.tfstate` no se sube a Git (contiene datos sensibles)
- Las manipulaciones de estado (`import`, `state rm`) solo existen en la CLI de Terraform
