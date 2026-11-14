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

resource "aws_iam_role" "api_instance" {
  name = "virtual-binder-api-runtime"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "api_logs" {
  role       = aws_iam_role.api_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
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

resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/virtual-binder-api"
  retention_in_days = 30
}

resource "aws_lambda_function" "api" {
  function_name = "virtual-binder-api"
  package_type  = "Image"
  image_uri     = var.api_image
  role          = aws_iam_role.api_instance.arn
  architectures = ["x86_64"]
  memory_size   = 2048
  timeout       = 300

  ephemeral_storage {
    size = 1024
  }

  environment {
    variables = var.cors_origins == "" ? {} : {
      CORS_ORIGINS = var.cors_origins
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.api,
    aws_iam_role_policy_attachment.api_logs,
  ]
}

resource "aws_lambda_function_url" "api" {
  function_name      = aws_lambda_function.api.function_name
  authorization_type = "NONE"
  invoke_mode        = "BUFFERED"
}

resource "aws_lambda_permission" "public_url" {
  statement_id           = "AllowPublicFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.api.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "public_invoke" {
  statement_id  = "AllowPublicFunctionUrlInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "*"
}
