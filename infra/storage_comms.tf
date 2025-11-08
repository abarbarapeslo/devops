# ==================================
# S3: Bucket para submissões
# ==================================
resource "aws_s3_bucket" "submissions" {
  bucket        = "${var.project_name}-${var.env}-submissions"
  force_destroy = false # Mantenha como 'false' em produção
  tags          = local.common_tags
}

resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.submissions.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.submissions.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.submissions.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ==================================
# SES: Identidades de E-mail
# ==================================
resource "aws_ses_email_identity" "sender" {
  email = var.ses_sender_email
}

resource "aws_ses_email_identity" "recipient" {
  email = var.ses_recipient_email
}