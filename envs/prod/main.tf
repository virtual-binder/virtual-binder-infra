data "aws_caller_identity" "current" {}

data "aws_ecr_repository" "containers" {
  name = "virtual-binder"
}

resource "aws_s3_bucket" "card_images" {
  bucket = "${data.aws_caller_identity.current.account_id}-virtual-binder-images"
}

resource "aws_s3_bucket_versioning" "card_images" {
  bucket = aws_s3_bucket.card_images.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "card_images" {
  bucket = aws_s3_bucket.card_images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "apprunner_ecr_access" {
  name = "virtual-binder-apprunner-ecr"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "apprunner.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "apprunner_ecr_access" {
  role = aws_iam_role.apprunner_ecr_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
      ]
      Resource = data.aws_ecr_repository.containers.arn
    }]
  })
}

resource "aws_iam_role" "api_instance" {
  name = "virtual-binder-api-runtime"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "apprunner.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "api_images" {
  role = aws_iam_role.api_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.card_images.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:PutObject",
        ]
        Resource = "${aws_s3_bucket.card_images.arn}/*"
      },
    ]
  })
}

resource "aws_apprunner_auto_scaling_configuration_version" "api" {
  auto_scaling_configuration_name = "virtual-binder-api"
  max_concurrency                 = 1
  max_size                        = var.api_max_instances
  min_size                        = var.api_min_instances
}

resource "aws_apprunner_service" "api" {
  service_name                   = "virtual-binder-api"
  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.api.arn

  source_configuration {
    auto_deployments_enabled = false

    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_ecr_access.arn
    }

    image_repository {
      image_identifier      = var.api_image
      image_repository_type = "ECR"

      image_configuration {
        port = "8000"
        runtime_environment_variables = var.cors_origins == "" ? {} : {
          CORS_ORIGINS = var.cors_origins
        }
      }
    }
  }

  instance_configuration {
    cpu               = "1024"
    memory            = "2048"
    instance_role_arn = aws_iam_role.api_instance.arn
  }

  health_check_configuration {
    healthy_threshold   = 1
    unhealthy_threshold = 5
    interval            = 5
    path                = "/health"
    protocol            = "HTTP"
    timeout             = 3
  }
}
