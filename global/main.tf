locals {
  environments = ["dev", "stag", "prod"]
}

# S3 bucket za čuvanje Terraform state-a
resource "aws_s3_bucket" "tf_state" {
  bucket = "mpopadic-tf-state-bucket"

  lifecycle {
    prevent_destroy = true
  }
}

# DynamoDB tabela za Terraform state locking
resource "aws_dynamodb_table" "tf_locks" {
  name         = "terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# AWS IAM OIDC Provajder za GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

# Kreiranje odvojenih IAM rola za dev, stag i prod okruženja
resource "aws_iam_role" "github_actions_env" {
  for_each = toset(local.environments)

  name = "github-actions-${each.key}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        StringLike = {
            "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_org}@${var.github_org_id}/${var.repository_name}@${var.repository_id}:environment:${each.key}",
            "repo:${var.github_org}/${var.repository_name}:environment:${each.key}",
            ]
          }
        }
      }
    ]
  })
}

# Dodela AdministratorAccess dozvola za svaku rolu
resource "aws_iam_role_policy_attachment" "env_admin" {
  for_each = toset(local.environments)

  role       = aws_iam_role.github_actions_env[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Outputi sa ARN-ovima rola za svako okruženje
output "aws_role_arns" {
  value = { for k, role in aws_iam_role.github_actions_env : k => role.arn }
}
