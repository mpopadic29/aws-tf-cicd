# aws-tf-cicd

Infrastructure as Code on AWS with a CI/CD pipeline in GitHub Actions. Terraform provisions three isolated environments (`dev`, `stag`, `prod`), and the pipeline authenticates to AWS with **OIDC**, so there are no long-lived access keys anywhere.

## Architecture

```
 Pull request ──► lint & validate (fmt, validate for all environments)
                        │
 Merge to main ─────────┤
                        ▼
                  deploy dev ──► deploy stag ──► deploy prod
                                                    ▲
                                          manual approval required
```

Each deploy job:

1. Requests a short-lived OIDC token from GitHub
2. Assumes that environment's IAM role in AWS (`sts:AssumeRoleWithWebIdentity`)
3. Runs `terraform init` and `terraform apply` against remote state

## What gets created

Per environment:

- **EC2 instance** with an IAM role and instance profile. The AMI is resolved automatically (latest Amazon Linux 2023 in the active region), so no hardcoded AMI IDs.
- **S3 bucket** for logs, encrypted and with public access blocked.

Shared, created once in `global/`:

- S3 bucket for Terraform state (versioning enabled)
- DynamoDB table for state locking
- GitHub OIDC identity provider
- One IAM role per environment, assumable only by that environment's jobs

Region: `eu-central-1`.

## Repository layout

```
.
├── .github/workflows/tf_deploy.yaml   # CI/CD pipeline
├── environments/{dev,stag,prod}/      # one root module per environment, separate state
├── modules/
│   ├── ec2/                           # EC2 + IAM role + instance profile
│   └── s3/                            # logs bucket
└── global/                            # bootstrap: state backend, OIDC provider, deploy roles
```

## Security design

- **No static credentials.** Authentication is OIDC with short-lived tokens.
- **One role per environment.** The trust policy of each role is bound to the repository and to a GitHub Environment, so the `dev` job cannot assume the `prod` role.
- **Trust policy** (example for dev):
  `repo:<owner>@<owner_id>/<repo>@<repo_id>:environment:dev`
  This repo uses GitHub's immutable subject claims (numeric owner and repo IDs), which also protects against repository rename or takeover.
- **Approval gate on prod.** The `prod` environment requires a reviewer before the job can start, and the role can only be assumed from that environment.
- **Protected `main`.** Changes require a pull request and at least one approving review.
- **Remote state** in S3 with versioning (rollback) and DynamoDB locking (no concurrent applies).
- `global/` is applied manually with admin credentials, never through the pipeline, so deploy roles cannot modify their own permissions.

## Setup

1. **Bootstrap** (once, local credentials):
   ```bash
   cd global
   terraform init && terraform apply
   ```
   The output `aws_role_arns` lists the role ARN for each environment.
2. **GitHub repository secrets:** store the role ARN for each environment.
3. **GitHub Environments:** `dev`, `stag`, `prod`. Add *Required reviewers* to `prod`.
4. **Branch protection** on `main`: require a pull request and one approval.

The workflow needs:

```yaml
permissions:
  id-token: write
  contents: read
```

Each deploy job declares `environment: <name>`. That is what puts `environment:<name>` into the OIDC token and makes the trust policy match.

## Local usage

```bash
cd environments/dev
terraform init
terraform plan
terraform fmt -recursive   # CI rejects unformatted code
```

Use the same Terraform version as pinned in the workflow. Never commit `*.tfstate` or `.terraform/`; do commit `.terraform.lock.hcl`.

## Lessons learned

| Problem | Cause | Fix |
|---|---|---|
| `Not authorized to perform sts:AssumeRoleWithWebIdentity` | OIDC `sub` claim did not match the trust policy (immutable claims include numeric IDs; the claim also changes with `environment:`) | Print the token claims in a debug step, then match the trust policy to the real `sub` |
| `openpgp: key expired` on `terraform init` | Terraform 1.6.0 rejects expired provider signing keys | Upgrade Terraform (pinned to the local version) |
| `InvalidAMIID.NotFound` | AMI ID was hardcoded for another region | Look up the AMI with a data source |

## Known limitations and next steps

- Deploy roles use `AdministratorAccess` for simplicity. The next step is a least-privilege policy scoped to EC2, S3, and the specific IAM actions needed.
- Add a Terraform version constraint (`required_version`) in the code.
- Consider S3 native state locking (Terraform 1.10+) in place of DynamoDB.

