output "api_url" {
  value = "https://${aws_apprunner_service.api.service_url}"
}

output "api_service_arn" {
  value = aws_apprunner_service.api.arn
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
