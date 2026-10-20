variable "environment" {
  type = string
}

resource "aws_s3_bucket" "logs_bucket" {
  bucket = "aws-tf-cicd-${var.environment}-logs-${random_string.suffix.result}"

  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket_server_side_encryption_configuration" "s3_encryption" {
  bucket = aws_s3_bucket.logs_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "s3_private" {
  bucket = aws_s3_bucket.logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "bucket_id" {
  value = aws_s3_bucket.logs_bucket.id
}
