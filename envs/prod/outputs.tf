output "api_url" {
  value = aws_lambda_function_url.api.function_url
}

output "api_function_arn" {
  value = aws_lambda_function.api.arn
}

output "ecr_repository_url" {
  value = data.aws_ecr_repository.containers.repository_url
}

output "images_bucket" {
  value = aws_s3_bucket.card_images.id
}

output "api_instance_role_arn" {
  value = aws_iam_role.api_instance.arn
}
