output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}

output "state_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}

output "infra_role_arn" {
  value = aws_iam_role.infra.arn
}

output "api_role_arn" {
  value = aws_iam_role.api.arn
}

output "ecr_repository_url" {
  value = aws_ecr_repository.containers.repository_url
}
