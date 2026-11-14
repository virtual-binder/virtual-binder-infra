# Arquitectura de Virtual Binder

Las líneas continuas representan el flujo del escáner actual. Las líneas punteadas indican recursos provisionados, integraciones futuras o automatización que requiere capacidades avanzadas de AWS.

```mermaid
flowchart LR
    Usuario[Usuario]

    subgraph Clientes[Clientes]
        Web[Web Next.js en Netlify]
        Mobile[App Android con Expo]
    end

    subgraph AWS[AWS · us-east-2]
        Lambda[Lambda + Function URL<br/>FastAPI · 2 GiB · escala a cero]
        ECR[(ECR<br/>Imágenes Docker)]
        S3[(S3 privado<br/>Imágenes de cartas)]
        Secrets[Secrets Manager<br/>Supabase y Mercado Pago]
        CloudWatch[CloudWatch<br/>Logs, métricas y alertas]
        Budgets[AWS Budgets<br/>Alertas de gasto]
        SNS[SNS<br/>Correo de operaciones]
    end

    subgraph CI[Integración y despliegue]
        CLI[AWS CLI local]
        GitHub[GitHub Actions]
        Terraform[Terraform]
        OIDC[OIDC + roles IAM]
    end

    TCG[TCGdex y Pokémon TCG]
    Supabase[(Supabase<br/>Perfiles, cartas y ventas)]
    MercadoPago[Mercado Pago<br/>Pagos y comisiones]
    Dominio[Dominio personalizado opcional]

    Usuario --> Web
    Usuario --> Mobile
    Web -->|HTTPS · multipart y JSON| Lambda
    Mobile -->|HTTPS · multipart y JSON| Lambda
    Lambda -->|Ficha y precios| TCG

    ECR -->|Imagen por digest| Lambda
    CLI -->|Build, prueba y push| ECR
    CLI --> Terraform
    Terraform -->|Despliegue| Lambda
    GitHub -.->|Requiere capacidades avanzadas| OIDC
    OIDC -.-> ECR
    OIDC -.-> Terraform

    Lambda --> CloudWatch
    CloudWatch --> SNS
    Budgets -->|Correo| Usuario

    Lambda -.->|Subida y lectura de imágenes| S3
    Lambda -.->|Leer valores cuando se integren| Secrets
    Lambda -.->|Perfiles y marketplace| Supabase
    Lambda -.->|Pagos| MercadoPago
    Dominio -.->|Mediante CloudFront, después| Lambda
```

## Estado de las integraciones

- **Operativo con el despliegue:** Lambda, Function URL, ECR, consulta de fuentes externas, logs, métricas, presupuesto y URL HTTPS proporcionada por AWS.
- **Provisionado, pendiente de código:** bucket de imágenes y lectura de secretos.
- **Bloqueado por la política actual del proyecto:** OIDC para CI/CD; el despliegue inicial se realiza con AWS CLI.
- **Etapas posteriores:** Supabase, perfiles, marketplace, Mercado Pago y dominio personalizado mediante CloudFront.
- **Fuera de AWS:** Netlify continúa alojando la web y Expo/EAS se usa para Android.
