# Bloco de configuração principal
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Tags padrão para todos os recursos
locals {
  common_tags = {
    Project   = var.project_name
    Env       = var.env
    ManagedBy = "Terraform"
  }
}

# 1. VPC (Nossa rede isolada)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(local.common_tags, { Name = "${var.project_name}-vpc" })
}

# 2. Subnets Públicas (para o Load Balancer)
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${10 + count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true # IPs públicos para o NAT Gateway
  tags = merge(local.common_tags, { Name = "${var.project_name}-public-${count.index + 1}" })
}

# 3. Subnets Privadas (para o App/Banco)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${20 + count.index}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = merge(local.common_tags, { Name = "${var.project_name}-private-${count.index + 1}" })
}

data "aws_availability_zones" "available" {
  state = "available"
}

# 4. Gateway de Internet (saída para o mundo)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(local.common_tags, { Name = "${var.project_name}-igw" })
}

# 5. Rota pública
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = merge(local.common_tags, { Name = "${var.project_name}-rt-public" })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}