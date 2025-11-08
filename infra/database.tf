# Gera uma senha forte e aleatória
resource "random_password" "db_password" {
  length  = 16
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# 1. Cria o Cofre de Senhas (Secrets Manager)
resource "aws_secretsmanager_secret" "db_creds" {
  name = "${var.project_name}/${var.env}/db_credentials"
  tags = local.common_tags
}

# 2. Guarda a senha e outros dados DENTRO do cofre
# A aplicação vai ler isso para se conectar.
resource "aws_secretsmanager_secret_version" "db_creds_version" {
  secret_id = aws_secretsmanager_secret.db_creds.id
  secret_string = jsonencode({
    username = "postgres_admin"
    password = random_password.db_password.result
    # O 'host' é preenchido com o endereço do RDS criado abaixo
    host     = aws_rds_cluster.db.endpoint
    port     = aws_rds_cluster.db.port
    dbname   = "meu_banco"
  })
}

# 3. Security Group (Firewall) do Banco
# Permite acesso APENAS pela porta 5432
resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Permite acesso ao RDS apenas pelo App"
  vpc_id      = aws_vpc.main.id
  tags        = local.common_tags

  # Acesso de entrada (ingress) será adicionado em 'application.tf'
  # para permitir APENAS o Security Group do App.

  # Acesso de saída (egress)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 4. Grupo de Subnet para o RDS (diz em quais subnets privadas ele pode rodar)
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [for s in aws_subnet.private : s.id]
  tags       = local.common_tags
}

# 5. Cria o Cluster de Banco de Dados (PostgreSQL Serverless)
# Usamos "serverless" pois é ideal para laboratórios (paga sob demanda)
resource "aws_rds_cluster" "db" {
  cluster_identifier      = "${var.project_name}-db-cluster"
  engine                  = "aurora-postgresql"
  engine_mode             = "provisioned" # 'serverless' é outra opção
  database_name           = "meu_banco"
  master_username         = "postgres_admin"
  master_password         = random_password.db_password.result
  db_subnet_group_name    = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  skip_final_snapshot     = true
  
  # Configuração para Aurora Serverless v2 (bom para dev/labs)
  serverlessv2_scaling_configuration {
    min_capacity = 0.5
    max_capacity = 1.0
  }
}