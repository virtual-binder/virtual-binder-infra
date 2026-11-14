# Virtual Binder Infrastructure

Infraestructura como código de [Virtual Binder](https://github.com/virtual-binder) usando Terraform y AWS.

Consulta el [diagrama de arquitectura](docs/architecture.md) para ver los clientes, despliegue, recursos AWS e integraciones previstas.

## Desarrollo local

La orquestación local usa Docker Compose para PostgreSQL y la API, y ejecuta Next.js y Expo directamente en el host para conservar la recarga rápida y el acceso a dispositivos.

Prerrequisitos: Docker Compose, Node.js, npm y Make. Los cuatro repositorios deben ser directorios hermanos.

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
- Opcionalmente, OIDC de GitHub y roles IAM separados para infraestructura y publicación de la API.

`envs/prod` define:

- Lambda con imagen Docker, 2 GiB, 300 segundos de espera máxima y escalado automático a cero.
- Function URL HTTPS pública para la API.
- Bucket S3 privado y versionado para imágenes de cartas.
- Role de ejecución con permisos separados para logs, imágenes y secretos.
- Secretos sin valores para Supabase y Mercado Pago.
- Logs y métricas de Lambda en CloudWatch, alerta de errores mediante SNS y presupuesto mensual con AWS Budgets.

Netlify y EAS se administran desde sus propias plataformas. Supabase se administra fuera de Terraform; las migraciones permanecerán en el repositorio de la API.

## Prerrequisitos

- Terraform 1.9 o superior.
- Un proyecto AWS con facturación configurada.
- AWS CLI autenticado con una identidad que pueda crear IAM, S3, DynamoDB, ECR y Lambda.

Ningún recurso se crea al clonar o publicar este repositorio.

## 1. Bootstrap único

Configura AWS CLI y comprueba el proyecto:

```bash
aws sts get-caller-identity --profile virtual-binder
cp bootstrap/terraform.tfvars.example bootstrap/terraform.tfvars
```

Con la nueva experiencia AWS, exporta las credenciales temporales para Terraform:

```bash
eval "$(aws configure export-credentials --profile virtual-binder --format env)"
```

Edita `bootstrap/terraform.tfvars` y ejecuta:

```bash
terraform -chdir=bootstrap init
terraform -chdir=bootstrap plan
terraform -chdir=bootstrap apply
terraform -chdir=bootstrap output
```

`enable_github_oidc=false` evita crear OIDC cuando la política de control del proyecto lo bloquea. Para activar CI/CD con OIDC, primero habilita las capacidades avanzadas correspondientes en AWS Settings y luego cambia la variable a `true`.

## 2. Publicación y producción

Publica la imagen en el repositorio ECR creado por bootstrap y guarda su digest en `envs/prod/terraform.tfvars` como `api_image`. Debe ser un digest inmutable, no `latest`.

Luego ejecuta:

```bash
terraform -chdir=envs/prod init \
  -backend-config="bucket=TU_BUCKET_DE_ESTADO" \
  -backend-config="dynamodb_table=TU_TABLA_DE_BLOQUEOS" \
  -backend-config="region=us-east-2" \
  -backend-config="key=virtual-binder/prod.tfstate"
terraform -chdir=envs/prod plan
terraform -chdir=envs/prod apply
```

Los archivos `terraform.tfvars`, planes y estado local están excluidos de Git. Los secretos se crean sin valores; agrega sus versiones con AWS Console o `aws secretsmanager put-secret-value`, nunca en Terraform ni GitHub.

La Function URL entrega HTTPS sin dominio propio. Un dominio personalizado puede agregarse después mediante CloudFront y ACM; no es necesario para el primer despliegue.

## CI/CD

- `terraform-plan.yml`: validación Terraform mediante OIDC.
- `deploy-api.yml`: despliegue manual o evento `api-image-built` usando el entorno `production`.
- `publish-api.yml`, en el repo de API: construye y prueba el contenedor, publica la imagen y envía su digest a `deploy-api.yml`.

Mientras OIDC esté bloqueado, los workflows de publicación y planes se ejecutan manualmente y el despliegue inicial se realiza con AWS CLI. Después de habilitar OIDC se pueden restaurar los disparadores automáticos.

Para la llamada entre repositorios, crea una GitHub App limitada a `virtual-binder-infra`, con permiso `Contents: write`. Guarda `INFRA_DISPATCH_APP_ID` y `INFRA_DISPATCH_PRIVATE_KEY` como secretos del repo de API; no uses un token personal amplio. Si el plan de GitHub lo permite, agrega aprobación requerida al entorno `production`.

## Control de costes

Lambda escala automáticamente a cero y no requiere pausar el servicio. Las imágenes se limitan a 4,4 MB para mantener la solicitud por debajo del límite de Function URL. Los presupuestos y las alertas informan, pero no detienen recursos ni gastos.

## Operación

Los cambios de memoria, permisos o alertas se realizan mediante pull request. No combines cambios manuales con la consola o AWS CLI en recursos administrados por Terraform, porque el siguiente plan podría revertirlos.

No registres imágenes, base64, tokens ni datos personales. Lambda envía logs y métricas estándar a CloudWatch; las métricas personalizadas deben mantener cardinalidad baja.
