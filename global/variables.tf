variable "github_org" {
  type        = string
  description = "GitHub username"
  default     = "mpopadic29"
}

variable "repository_name" {
  type        = string
  description = "GitHub repo name"
  default     = "aws-tf-cicd"
}

variable "aws_region" {
  type        = string
  default     = "eu-central-1"
}
