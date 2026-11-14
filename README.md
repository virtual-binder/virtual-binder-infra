# Virtual Binder Infrastructure

Infraestructura como código de [Virtual Binder](https://github.com/virtual-binder) usando Terraform y AWS.

## Desarrollo local

La orquestación local usa Docker Compose para PostgreSQL y la API, y ejecuta Next.js y Expo directamente en el host para conservar la recarga rápida y el acceso a dispositivos.

Prerequisitos: Docker Compose, Node.js, npm y Make. Los cuatro repositorios deben ser directorios hermanos.

```bash
cp .env.example .env
make install
make dev
```

`make dev` construye la API, levanta PostgreSQL, inicia Next.js en `http://localhost:3000` y Expo para Android/iOS. Al presionar Ctrl+C detiene los procesos y contenedores, conservando el volumen de PostgreSQL.

Comandos útiles:

```bash
make up       # Solo PostgreSQL y API, en segundo plano
make web      # Solo Next.js
make mobile   # Solo Expo
make logs     # Logs de API y PostgreSQL
make status   # Estado de los contenedores
make down     # Detener contenedores sin borrar datos
make config   # Validar Compose
```

La API queda en `http://localhost:8000/docs`. El emulador Android usa `http://10.0.2.2:8000`; para un teléfono físico, configura `EXPO_PUBLIC_API_URL` con la IP local del equipo. El navegador usa `NEXT_PUBLIC_API_URL=http://localhost:8000`.

## Repositorios relacionados

- [`virtual-binder-api`](https://github.com/virtual-binder/virtual-binder-api): API FastAPI e imágenes de contenedor.
- [`virtual-binder-mobile`](https://github.com/virtual-binder/virtual-binder-mobile): app Expo.
- [`virtual-binder-web`](https://github.com/virtual-binder/virtual-binder-web): marketplace web.

## Recursos administrados

`bootstrap` crea:

- Bucket S3 privado y versionado para el estado de Terraform.
- Tabla DynamoDB bajo demanda para bloquear el estado.
- Repositorio ECR con escaneo y retención de diez imágenes.
- OIDC de GitHub y roles IAM separados para infraestructura y publicación de la API.

`envs/prod` define:

- App Runner para la API: 1 vCPU, 2 GiB, concurrencia 1 y máximo 2 instancias.
- Una instancia mínima inicial para evitar arranques fríos durante la evaluación.
- Bucket S3 privado y versionado para imágenes de cartas.
- Roles separados para acceso a ECR y ejecución de la API.
- Secretos sin valores para Supabase y Mercado Pago.
- Logs y métricas de App Runner en CloudWatch, alerta 5xx mediante SNS y presupuesto mensual con AWS Budgets.

Netlify y EAS se administran desde sus propias plataformas. Supabase se administra fuera de Terraform; las migraciones permanecerán en el repositorio de la API.

## Prerrequisitos

- Terraform 1.9 o superior.
- Una cuenta AWS con facturación y créditos configurados.
- AWS CLI autenticado con una identidad que pueda crear IAM, S3, DynamoDB y ECR.

Ningún recurso se crea al clonar o publicar este repositorio.

## 1. Bootstrap único

Configura AWS CLI con SSO o el método de autenticación elegido y comprueba la cuenta:

```bash
aws sts get-caller-identity
cp bootstrap/terraform.tfvars.example bootstrap/terraform.tfvars
```

Edita `bootstrap/terraform.tfvars` y ejecuta:

```bash
terraform -chdir=bootstrap init
terraform -chdir=bootstrap plan
terraform -chdir=bootstrap apply
terraform -chdir=bootstrap output
```

Guarda los outputs como variables de GitHub:

| Repositorio | Variable | Contenido |
| --- | --- | --- |
| API | `AWS_ACCOUNT_ID` | ID numérico de la cuenta AWS |
| API e infra | `AWS_REGION` | Región AWS; normalmente `us-east-1` |
| API | `AWS_API_ROLE_ARN` | ARN del role que publica en ECR |
| Infra | `AWS_INFRA_ROLE_ARN` | ARN del role que aplica Terraform |
| Infra | `TF_STATE_BUCKET` | Bucket de estado |
| Infra | `TF_STATE_TABLE` | Tabla DynamoDB de bloqueos |
| Infra | `CORS_ORIGINS` | Orígenes web permitidos, separados por comas |
| Infra | `API_IMAGE` | Digest usado por los planes manuales |

Agrega `ALERT_EMAIL` como secreto del repo de infraestructura. La suscripción SNS y las alertas de presupuesto requieren confirmación por correo.

## 2. Producción

Una vez publicada la primera imagen en ECR, para una aplicación local:

```bash
cp envs/prod/terraform.tfvars.example envs/prod/terraform.tfvars
terraform -chdir=envs/prod init \
  -backend-config="bucket=TU_BUCKET_DE_ESTADO" \
  -backend-config="dynamodb_table=TU_TABLA_DE_BLOQUEOS" \
  -backend-config="region=us-east-1" \
  -backend-config="key=virtual-binder/prod.tfstate"
terraform -chdir=envs/prod plan
terraform -chdir=envs/prod apply
```

`api_image` debe ser un digest inmutable publicado en ECR, no `latest`. Los archivos `terraform.tfvars` y el estado están excluidos de Git.

Los secretos se crean sin valores deliberadamente. Agrega sus versiones con AWS Console o `aws secretsmanager put-secret-value`; nunca los pongas en Terraform ni GitHub.

## CI/CD

- `terraform-plan.yml`: valida pull requests mediante OIDC, sin credenciales JSON permanentes.
- `deploy-api.yml`: despliegue manual o evento `api-image-built` usando el entorno `production`.
- `publish-api.yml`, en el repo de API: construye y prueba el contenedor, publica la imagen y envía su digest a `deploy-api.yml`.

Si el plan de GitHub lo permite, configura `production` con aprobación requerida. Si no, usa el despliegue manual como puerta de control antes de producción.

Para la llamada entre repositorios, crea una GitHub App limitada a `virtual-binder-infra`, con permiso `Contents: write`. Guarda `INFRA_DISPATCH_APP_ID` y `INFRA_DISPATCH_PRIVATE_KEY` como secretos del repo de API; no uses un token personal amplio.

## Control de costes

App Runner no escala automáticamente a cero. Para detener el coste del servicio cuando termine la evaluación:

```bash
aws apprunner pause-service --service-arn TU_SERVICE_ARN
aws apprunner resume-service --service-arn TU_SERVICE_ARN
```

El ARN queda disponible en el output `api_service_arn`. Los presupuestos y las alertas informan, pero no detienen recursos ni gastos.

## Operación

Los cambios de instancias, memoria, permisos o alertas se realizan mediante pull request. No combines cambios manuales con la consola o AWS CLI en recursos administrados por Terraform, porque el siguiente plan podría revertirlos.

No registres imágenes, base64, tokens ni datos personales. App Runner envía logs y métricas estándar a CloudWatch; las métricas personalizadas deben mantener cardinalidad baja.
