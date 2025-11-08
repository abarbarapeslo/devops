output "alb_dns_name" {
  description = "A URL pública do Load Balancer. Acesse http://<url>/"
  value       = aws_lb.app_lb.dns_name
}

output "ecr_repository_url" {
  description = "A URL do repositório ECR para onde o CI/CD deve enviar a imagem."
  value       = aws_ecr_repository.app.repository_url
}

output "s3_bucket_name" {
  description = "Bucket onde os JSONs de submissões serão salvos."
  value       = aws_s3_bucket.submissions.bucket
}

output "database_secret_arn" {
  description = "ARN do cofre de senhas do banco de dados."
  value       = aws_secretsmanager_secret.db_creds.arn
}