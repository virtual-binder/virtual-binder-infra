output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}

output "state_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}

output "infra_role_arn" {
  value = var.enable_github_oidc ? aws_iam_role.infra[0].arn : null
}

output "api_role_arn" {
  value = var.enable_github_oidc ? aws_iam_role.api[0].arn : null
}

output "ecr_repository_url" {
  value = aws_ecr_repository.containers.repository_url
}
