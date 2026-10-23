# aws-tf-cicd

Terraform on AWS with a GitHub Actions pipeline. It manages three environments (dev, stag, prod) and deploys them without any stored AWS keys, using GitHub OIDC.

## How it works

- **Pull request:** formatting check and `terraform validate` for every environment. Nothing is deployed.
- **Merge to main:** deploys dev, then stag, then plans prod.
- **Prod:** the plan is saved and shown in the job summary. A reviewer has to approve it manually, and then exactly that plan is applied.

Each deploy job gets a short-lived token from GitHub and assumes the IAM role of its environment. Every role only trusts its own GitHub environment, so the dev job can't touch prod.

## What it creates

Per environment: an EC2 instance (latest Amazon Linux 2023, with an IAM role) and an encrypted S3 bucket for logs.

Shared, in `global/`: the S3 bucket for Terraform state (versioned, locking with S3 lock files), the GitHub OIDC provider, and one IAM role per environment.

## Structure

```
.github/workflows/tf_deploy.yaml   pipeline
environments/dev|stag|prod/        one root module per environment
modules/ec2, modules/s3            shared modules
global/                            state bucket, OIDC provider, deploy roles
```

## Setup

1. Run once, locally: `cd global && terraform init && terraform apply`. The output lists the role ARNs.
2. Add repository variables `AWS_ROLE_DEV`, `AWS_ROLE_STAG`, `AWS_ROLE_PROD` with those ARNs.
3. Create the GitHub environments `dev`, `stag`, `prod` and `prod-plan`. Limit them to the `main` branch and add a required reviewer to `prod`.
4. Protect `main`: pull request and one approval required.

## Problems I ran into

- **OIDC role assume failed.** The token's `sub` claim contains numeric IDs and the environment name, so my trust policy didn't match. I printed the token claims and fixed the policy.
- **Provider install failed (`key expired`).** Terraform 1.6.0 was too old, so I upgraded.
- **AMI not found.** I had hardcoded an AMI from another region. It is now looked up, and the instance ignores later AMI updates so prod isn't rebuilt by itself.
- **Pull requests were deploying.** Deploy jobs now run only on push to `main`.

## Not done yet

- The deploy roles have `AdministratorAccess` and should be scoped down.
- One state bucket is shared by all environments. I would split prod from non-prod.
- EC2 hardening: IMDSv2, encrypted root volume, a security group.
- Run a plan on pull requests.
