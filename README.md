# AUY1103 - Actividad 2.1 – The Cheese Factory con Módulos Públicos y Estado Remoto

Este repositorio implementa la solución de la **Actividad 2.1** del ramo **AUY1103**, basada en el escenario
de *The Cheese Factory*. Se toma como punto de partida la evaluación EA1 (3 servidores web detrás de un ALB),
pero ahora con una infraestructura **modular, segura y con estado remoto**, siguiendo las indicaciones del docente.

La solución está pensada para ejecutarse en una cuenta de **laboratorio AWS Academy**, por lo que **no crea
recursos IAM** adicionales (usuarios, roles, políticas). Solo se utilizan servicios como **VPC, EC2, ALB, S3,
DynamoDB y Security Groups**.

---

## 1. Estructura del repositorio

```text
cheese_factory_act2_terraform/
├── README.md
├── .gitignore
├── s3-backend-bootstrap/
│   ├── versions.tf
│   ├── variables.tf
│   ├── locals.tf
│   ├── main.tf
│   └── outputs.tf
└── app-infra/
    ├── versions.tf
    ├── providers.tf
    ├── variables.tf
    ├── locals.tf
    ├── vpc.tf
    ├── security_groups.tf
    ├── ec2_alb.tf
    ├── user_data.sh.tpl
    ├── outputs.tf
    └── terraform.tfvars.example
```

- **`s3-backend-bootstrap/`**: proyecto independiente que crea el **bucket S3** y la **tabla DynamoDB** que se
  usarán como backend remoto del estado de Terraform (módulo público `terraform-aws-modules/s3-bucket/aws`).
- **`app-infra/`**: proyecto principal que despliega la VPC, subredes, ALB y 3 EC2 en subredes privadas usando
  el módulo público `terraform-aws-modules/vpc/aws` y el backend remoto definido arriba.

Todo el código utiliza el contexto del estudiante **Daniel Tapia** (`dtapia`) como `owner`, tanto en nombres como en tags.

---

## 2. Configuración de credenciales (AWS Academy)

Antes de ejecutar Terraform, debes tener configuradas las credenciales del laboratorio (Access key, Secret key,
Session token). Puedes hacerlo de dos formas:

### Opción A: archivo `~/.aws/credentials`

Copia el bloque que entrega Cloud Access en el lab y crea el archivo:

```ini
[default]
aws_access_key_id=TU_ACCESS_KEY
aws_secret_access_key=TU_SECRET_KEY
aws_session_token=TU_SESSION_TOKEN
```

### Opción B: variables de entorno (PowerShell / terminal VS Code)

```powershell
$Env:AWS_ACCESS_KEY_ID     = "TU_ACCESS_KEY"
$Env:AWS_SECRET_ACCESS_KEY = "TU_SECRET_KEY"
$Env:AWS_SESSION_TOKEN     = "TU_SESSION_TOKEN"
$Env:AWS_REGION            = "us-east-1"
```

Con eso, tanto **AWS CLI** como **Terraform** podrán autenticarse sin hardcodear credenciales en el código.

---

## 3. Proyecto 1 – `s3-backend-bootstrap/` (módulo S3 + DynamoDB)

Este proyecto crea el backend remoto de Terraform usando el módulo público
`terraform-aws-modules/s3-bucket/aws`:

- Bucket S3 para el estado remoto: nombre derivado de `project` + `owner`, por ejemplo:
  `cheese-factory-tfstate-dtapia`.
- Tabla DynamoDB para locks: `cheese-factory-tf-locks-dtapia`.
- Bucket privado, con **versioning habilitado** y **bloqueo de acceso público**.

> Este proyecto se ejecuta **una vez** para preparar el backend. Después de eso, otros proyectos (como `app-infra/`)
> pueden usar ese bucket/tabla como backend remoto.

**Pasos sugeridos:**

```bash
cd s3-backend-bootstrap

# Primer despliegue: sin backend remoto (state local)
terraform init -backend=false

terraform plan
terraform apply
```

Al final puedes revisar los nombres reales con:

```bash
terraform output
```

---

## 4. Proyecto 2 – `app-infra/` (VPC, ALB y EC2 con módulos públicos)

Este proyecto consume el backend remoto creado arriba y despliega la infraestructura principal:

- VPC creada con el módulo `terraform-aws-modules/vpc/aws`.
- 3 subredes **públicas** y 3 subredes **privadas** en AZs distintas.
- Application Load Balancer en subredes públicas.
- 3 instancias EC2 en subredes privadas, detrás del ALB.
- Security Groups con principio de mínimo privilegio.
- Script `user_data` que instala Apache y muestra el entorno (`dev` o `prod`) y el hostname.

### 4.1. Variable `environment` y tipos de instancia

La variable `environment` (definida en `variables.tf` y seteada en `terraform.tfvars`) controla el tipo
de instancia EC2 mediante una **expresión condicional**:

- `environment = "dev"` → `t2.micro`
- `environment = "prod"` → `t3.small`

Esta lógica se implementa en `locals.tf` con:

```hcl
instance_type = var.environment == "prod" ? "t3.small" : "t2.micro"
```

### 4.2. Funciones nativas usadas

- `format()` para construir nombres (`name_prefix`, tags `Name`, etc.).
- `merge()` para combinar tags base con tags adicionales del usuario.
- `slice()` para seleccionar las primeras 3 zonas de disponibilidad.
- `trimspace()` para normalizar la IP pública retornada por `https://checkip.amazonaws.com/`.
- Expresiones condicionales para escoger `instance_type` y el CIDR de SSH.

### 4.3. Security Groups

De acuerdo al enunciado:

- **Security Group del ALB**:
  - Permite HTTP (puerto 80) desde `0.0.0.0/0`.
- **Security Group de las EC2**:
  - HTTP (80) **solo** desde el SG del ALB.
  - SSH (22) **solo** desde tu IP pública (`admin_ssh_cidr` o autodescubierta mediante `data "http" "myip"`).

### 4.4. Backend remoto en `providers.tf`

En `app-infra/providers.tf` se configura el backend S3 de Terraform con el bucket y la tabla creados por el
proyecto `s3-backend-bootstrap`:

```hcl
terraform {
  backend "s3" {
    bucket         = "cheese-factory-tfstate-dtapia"
    key            = "app-infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "cheese-factory-tf-locks-dtapia"
    encrypt        = true
  }
}
```

Si cambias `project` u `owner` en el bootstrap, recuerda actualizar estos nombres.

---

## 5. `terraform.tfvars` y ejemplo de valores

En `app-infra/terraform.tfvars.example` tienes un archivo de ejemplo. Para trabajar en serio:

1. Copia ese archivo como `terraform.tfvars`.
2. Ajusta al menos:
   - `environment` → `"dev"` o `"prod"`.
   - `region` → normalmente `"us-east-1"` en el lab.
   - `admin_ssh_cidr` → tu IP pública con `/32` (o déjalo vacío para autodetección).

Ejemplo mínimo:

```hcl
project        = "cheese-factory"
owner          = "dtapia"
environment    = "dev"
region         = "us-east-1"
admin_ssh_cidr = "1.2.3.4/32"

additional_tags = {
  OwnerFullName = "Daniel Tapia"
}
```

---

## 6. Comandos principales (flujo recomendado)

```bash
# 1) Backend remoto (solo una vez)
cd s3-backend-bootstrap
terraform init -backend=false
terraform apply

# 2) Infraestructura principal
cd ../app-infra
terraform init
terraform plan
terraform apply
```

Al terminar el `apply`, anota el output:

```bash
terraform output alb_dns_name
```

Copia ese DNS en el navegador; deberías ver la página de *The Cheese Factory* con el `hostname` y el `environment`.

Cuando termines la actividad, destruye los recursos para no seguir usando créditos del laboratorio:

```bash
cd app-infra
terraform destroy

cd ../s3-backend-bootstrap
terraform destroy
```

---

## 7. Checklist frente al enunciado del profe

- ✅ Variable `environment` con cambios reales en la infraestructura (tipo de instancia).
- ✅ Uso de `.tfvars` y archivo `terraform.tfvars.example` en el repositorio.
- ✅ Uso del módulo público `terraform-aws-modules/vpc/aws` para la red.
- ✅ Uso del módulo público `terraform-aws-modules/s3-bucket/aws` para el backend S3.
- ✅ Proyecto separado `s3-backend-bootstrap` para backend + DynamoDB.
- ✅ ALB en subredes públicas, EC2 en subredes privadas.
- ✅ Security Groups siguiendo mínimo privilegio (HTTP desde el ALB, SSH solo desde la IP del alumno).
- ✅ Expresiones condicionales y funciones nativas (`format`, `merge`, `slice`, `trimspace`).
- ✅ Gestión de código con estructura clara y README explicativo.

Con este proyecto deberías cubrir todos los puntos técnicos que se revisan en la Actividad 2.1.
