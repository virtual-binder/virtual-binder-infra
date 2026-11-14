# Virtual Binder Infrastructure

Infraestructura como código de [Virtual Binder](https://github.com/virtual-binder) usando Terraform y Google Cloud.

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

`envs/prod` define:

- APIs de Google Cloud necesarias.
- Artifact Registry para imágenes Docker.
- Cloud Run para la API: 1 vCPU, 2 GiB, concurrencia 1 y máximo 2 instancias.
- Una instancia mínima inicial para evitar arranques fríos durante la evaluación; `api_min_instances = 0` la desactiva.
- Bucket privado y versionado para imágenes de cartas.
- Cuenta de servicio de ejecución con permisos separados.
- Secretos sin valores para PostgreSQL y Mercado Pago.
- Logging, Monitoring, trazas automáticas de Cloud Run, chequeo `/health` y alertas por correo.
- Presupuesto mensual de USD 100 con alertas al 25%, 50%, 75% y 90%. Las alertas no detienen recursos ni gastos.

Netlify y EAS se administran desde sus propias plataformas. Cloud SQL queda fuera inicialmente para evitar un coste fijo.

## Prerequisitos

- Terraform 1.9 o superior.
- Un proyecto GCP con facturación y créditos configurados.
- Permisos para crear recursos, cuentas de servicio e IAM.
- Google Cloud CLI para el bootstrap local.

Ningún recurso se crea al clonar o publicar este repositorio.

## 1. Bootstrap único

El bootstrap crea el bucket remoto de estado, Artifact Registry, cuentas de servicio separadas para CI e infraestructura y Workload Identity Federation limitado a los repos `virtual-binder-api` y `virtual-binder-infra`. Su estado local está excluido de Git.

```bash
gcloud auth application-default login
gcloud config set project TU_PROYECTO_GCP
gcloud services enable serviceusage.googleapis.com cloudresourcemanager.googleapis.com
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

| Variable | Contenido |
| --- | --- |
| `GCP_PROJECT_ID` | ID del proyecto GCP |
| `GCP_SERVICE_ACCOUNT` | Email de la cuenta de servicio de infraestructura |
| `GCP_API_SERVICE_ACCOUNT` | Email de la cuenta CI; se configura en el repo de API |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Nombre completo del provider OIDC |
| `TF_STATE_BUCKET` | Bucket de estado |
| `GCP_BILLING_ACCOUNT` | ID de facturación; vacío deshabilita el presupuesto |
| `GCP_REGION` | Región de GCP; normalmente `us-central1` |
| `CORS_ORIGINS` | Orígenes web permitidos, separados por comas |
| `API_IMAGE` | Digest inicial usado en los planes |

Agrega `ALERT_EMAIL` como secreto de GitHub. Para usar el presupuesto, la identidad que aplique Terraform necesita permiso de administración de presupuestos en la cuenta de facturación.

## 2. Producción

Para una aplicación local:

```bash
cp envs/prod/terraform.tfvars.example envs/prod/terraform.tfvars
terraform -chdir=envs/prod init \
  -backend-config="bucket=TU_BUCKET_DE_ESTADO" \
  -backend-config="prefix=virtual-binder/prod"
terraform -chdir=envs/prod plan
terraform -chdir=envs/prod apply
```

`api_image` debe ser un digest inmutable publicado en Artifact Registry, no `latest`. Los archivos `terraform.tfvars` y el estado están excluidos de Git.

Los secretos se crean vacíos deliberadamente. Agrega sus valores con Google Cloud Console o `gcloud secrets versions add`; nunca los pongas en Terraform ni GitHub.

## CI/CD

- `terraform-plan.yml`: valida pull requests mediante OIDC, sin credenciales JSON permanentes.
- `deploy-api.yml`: despliegue manual o evento `api-image-built`, protegido por el entorno GitHub `production`.
- `publish-api.yml`, en el repo de API: construye y prueba el contenedor, publica la imagen y envía su digest a `deploy-api.yml`.

Configura `production` con aprobación requerida antes del primer despliegue. El bootstrap crea identidades OIDC separadas para infraestructura y para publicar imágenes; la cuenta CI de la API solo recibe `Artifact Registry Writer` sobre este repositorio de contenedores.

Para la llamada entre repositorios, crea una GitHub App limitada a `virtual-binder-infra`, con permiso `Contents: write`. Guarda `INFRA_DISPATCH_APP_ID` y `INFRA_DISPATCH_PRIVATE_KEY` como secretos del repo de API; no uses un token personal amplio.

Cuando se incorpore PostgreSQL, las migraciones se ejecutarán como un Cloud Run Job independiente antes de mover el tráfico.

## Operación

Los cambios de instancias, memoria, permisos o alertas se realizan mediante pull request. No combines cambios manuales con `gcloud run services update`, porque Terraform podría revertirlos.

Cloud Logging conserva los logs durante 30 días por defecto. No registres imágenes, base64, tokens ni datos personales. Las métricas estándar de GCP y las trazas automáticas de Cloud Run reducen el consumo; las métricas y spans personalizados deben mantener cardinalidad baja.
