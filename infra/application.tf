# 1. Repositório de Imagens (ECR)
# O CI/CD (main.yml) vai enviar a imagem Docker para cá.
resource "aws_ecr_repository" "app" {
  name                 = var.project_name
  image_tag_mutability = "MUTABLE"
  tags                 = local.common_tags
}

# 2. Load Balancer (ALB) - A porta de entrada pública
resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Permite tráfego web (HTTP) para o ALB"
  vpc_id      = aws_vpc.main.id
  tags        = local.common_tags

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Permite acesso da internet
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "app_lb" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [for s in aws_subnet.public : s.id]
  tags               = local.common_tags
}

# 3. Target Group (Para onde o ALB envia o tráfego)
resource "aws_lb_target_group" "app_tg" {
  name        = "${var.project_name}-tg"
  port        = 8000 # A porta que o Uvicorn usa dentro do Docker
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip" # Necessário para Fargate

  health_check {
    path                = "/" # Seu FastAPI precisa responder 200 OK em "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
  tags = local.common_tags
}

# 4. Listener (Ouvinte) do ALB
# Escuta na porta 80 e encaminha para o Target Group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# 5. Cluster ECS (O "agrupamento" lógico dos containers)
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
  tags = local.common_tags
}

# 6. Security Group do App
# Permite tráfego APENAS do ALB e libera acesso ao Banco
resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg"
  description = "Permite tráfego do ALB para o App"
  vpc_id      = aws_vpc.main.id
  tags        = local.common_tags

  # Entrada: Apenas do ALB na porta 8000
  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # Saída: Libera tudo para o App poder falar com S3, SES, e o Banco
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Libera o acesso do App (app_sg) para o Banco (db_sg)
resource "aws_security_group_rule" "app_to_db" {
  type                     = "ingress"
  from_port                = 5432 # Porta do PostgreSQL
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app_sg.id
  security_group_id        = aws_security_group.db_sg.id
}


# 7. Definição da Tarefa ECS (A "receita" do container)
resource "aws_ecs_task_definition" "app_task" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"  # 0.25 vCPU
  memory                   = "512"  # 0.5 GB RAM
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  # Definição do container principal
  container_definitions = jsonencode([{
    name  = "${var.project_name}-container"
    # 👇 Pega a imagem e tag do ECR e da variável do CI/CD
    image = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
    portMappings = [{
      containerPort = 8000 # Porta do Uvicorn
      hostPort      = 8000
    }]

    # 👇 Variáveis de Ambiente (NÃO-SECRETAS)
    environment = [
      { name = "BUCKET_NAME", value = aws_s3_bucket.submissions.bucket },
      { name = "SES_SENDER_EMAIL", value = var.ses_sender_email },
      { name = "SES_RECIPIENT_EMAIL", value = var.ses_recipient_email }
      # O main.py deve ler o host/user/dbname do cofre
    ]

    # 👇 Injeção de SEGREDOS do Secrets Manager
    # O Fargate pega o valor do cofre e injeta como variável de ambiente
    secrets = [
      {
        name      = "DB_CREDS_JSON" # Nome da variável (ex: os.environ.get("DB_CREDS_JSON"))
        valueFrom = aws_secretsmanager_secret.db_creds.arn
      }
    ]

    # Configuração de Logs
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app_logs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = local.common_tags
}

# 8. Grupo de Logs
resource "aws_cloudwatch_log_group" "app_logs" {
  name = "/ecs/${var.project_name}"
  tags = local.common_tags
}

# 9. Serviço ECS (Roda e mantém a tarefa viva)
resource "aws_ecs_service" "app_service" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app_task.arn
  desired_count   = 1 # Queremos 1 cópia do container rodando
  launch_type     = "FARGATE"
  
  # Para o CI/CD conseguir fazer deploy sem downtime
  enable_ecs_managed_tags = true
  propagate_tags          = "SERVICE"

  network_configuration {
    subnets         = [for s in aws_subnet.private : s.id] # Roda o app na rede privada
    security_groups = [aws_security_group.app_sg.id]
  }

  # Conecta o serviço ao Load Balancer
  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "${var.project_name}-container"
    container_port   = 8000
  }

  # Espera o ALB estar pronto antes de iniciar o serviço
  depends_on = [aws_lb_listener.http]
}