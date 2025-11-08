# Variável injetada pelo pipeline de CI/CD (main.yml)
variable "image_tag" {
  description = "A tag da imagem Docker vinda do CI/CD (ex: o hash do commit)."
  type        = string
}

variable "project_name" {
  description = "Nome curto do projeto para compor recursos."
  type        = string
  default     = "formstack"
}

variable "env" {
  description = "Ambiente lógico (dev, stage, prod)."
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "Região AWS para todos os recursos."
  type        = string
  default     = "us-east-1"
}

# -----------------------------------------------------------------
# Variáveis que DEVEM ser preenchidas (ex: em terraform.tfvars)
# -----------------------------------------------------------------

variable "ses_sender_email" {
  description = "E-mail verificado no SES que será usado como remetente."
  type        = string
  # Sem padrão, força o usuário a definir
}

variable "ses_recipient_email" {
  description = "E-mail que receberá as notificações."
  type        = string
  # Sem padrão, força o usuário a definir
}