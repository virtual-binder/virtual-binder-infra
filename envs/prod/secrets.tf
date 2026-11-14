locals {
  secret_ids = toset([
    "database-url",
    "mercadopago-access-token",
    "mercadopago-webhook-secret",
  ])
}

resource "aws_secretsmanager_secret" "api" {
  for_each = local.secret_ids

  name                    = "virtual-binder/${each.value}"
  recovery_window_in_days = 7
}

resource "aws_iam_role_policy" "api_secrets" {
  role = aws_iam_role.api_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = values(aws_secretsmanager_secret.api)[*].arn
    }]
  })
}
