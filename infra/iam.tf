# 1. Role de Execução da Tarefa (Task Execution Role)
# Permissão que o Fargate usa para:
# - Baixar a imagem do ECR
# - Enviar logs para o CloudWatch
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = local.common_tags
}

# Anexa a política gerenciada da AWS
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}


# 2. Role da Tarefa (Task Role)
# ESTA É A ROLE QUE SEU CÓDIGO 'boto3' NO 'main.py' VAI USAR.
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
  tags = local.common_tags
}

# 3. Política de Permissões da Aplicação
resource "aws_iam_policy" "app_policy" {
  name   = "${var.project_name}-app-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:PutObject"],
        Resource = ["${aws_s3_bucket.submissions.arn}/*"]
      },
      {
        Effect = "Allow",
        Action = ["ses:SendEmail"],
        Resource = "*" # SES requer "*" para SendEmail
      },
      {
        Effect = "Allow",
        Action = ["secretsmanager:GetSecretValue"],
        # Permite ler APENAS o segredo do banco de dados
        Resource = [aws_secretsmanager_secret.db_creds.arn]
      }
    ]
  })
}

# 4. Anexa a política à Role
resource "aws_iam_role_policy_attachment" "app_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.app_policy.arn
}