variable "environment" {
  type = string
}

variable "ami_id" {
  type        = string
  default     = null
  description = "Opcionalno. Ako nije zadat, koristi se najnoviji Amazon Linux 2023 u regiji."
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
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
  ami                  = coalesce(var.ami_id, data.aws_ami.al2023.id)
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name        = "app-server-${var.environment}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
  lifecycle {
    ignore_changes = [ami]
  }
}

output "instance_id" {
  value = aws_instance.app_server.id
}
