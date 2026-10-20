variable "environment" {
  type = string
}

variable "ami_id" {
  type    = string
  default = "ami-092cce4a19b438926" # Amazon Linux 2023 u eu-north-1
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2-${var.environment}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-${var.environment}-instance-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_instance" "app_server" {
  ami                  = var.ami_id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name        = "app-server-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

output "instance_id" {
  value = aws_instance.app_server.id
}
