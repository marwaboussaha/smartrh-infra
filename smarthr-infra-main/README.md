# SmartHR — Terraform Infrastructure

## Structure

```
smarthr-infra/
├── main.tf                  # Root: wires all modules together
├── variables.tf             # All input variable declarations
├── outputs.tf               # Useful outputs (ALB DNS, etc.)
├── terraform.tfvars         # Non-sensitive values (committed)
├── .checkov.yaml            # Checkov security scanner config
├── import.sh                # One-time import of existing resources
├── .github/
│   └── workflows/
│       └── infra.yml        # CI/CD: security scan → validate → plan → apply
└── modules/
    ├── vpc/                 # VPC, subnets, IGW, NAT GW, flow logs
    ├── alb/                 # ALB, target group, HTTPS listeners, S3 logs
    ├── rds/                 # RDS MySQL Multi-AZ, subnet group, monitoring
    ├── secrets/             # Secrets Manager: DB_HOST, APP_KEY, DB_PASSWORD
    ├── ecs/                 # ECS cluster, task defs, services, IAM, Service Connect
    └── monitoring/          # CloudWatch alarms, SNS, dashboard
```

## Prerequisites

1. AWS CLI configured: `aws configure`
2. Terraform >= 1.5 installed
3. S3 backend bucket and DynamoDB lock table exist:

```bash
# Create S3 state bucket
aws s3 mb s3://smarthr-terraform-state --region us-east-1
aws s3api put-bucket-versioning \
  --bucket smarthr-terraform-state \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption \
  --bucket smarthr-terraform-state \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# Create DynamoDB lock table
aws dynamodb create-table \
  --table-name smarthr-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

## First-time setup (existing infrastructure)

```bash
cd smarthr-infra

# Set sensitive values via environment — never put these in tfvars
export TF_VAR_db_password="your_rds_password"
export TF_VAR_app_key="base64:your_laravel_app_key"

# Import existing AWS resources into Terraform state
chmod +x import.sh
./import.sh

# Review what Terraform wants to change
terraform plan

# Apply — only after verifying plan shows no unexpected destroys
terraform apply
```

## Deploying changes

```bash
export TF_VAR_db_password="..."
export TF_VAR_app_key="..."
terraform plan -out=tfplan
terraform apply tfplan
```

## GitHub Actions secrets required

Add these in your repo → Settings → Secrets → Actions:

| Secret                  | Value                              |
|-------------------------|------------------------------------|
| `AWS_ACCESS_KEY_ID`     | IAM user access key                |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key                |
| `DB_PASSWORD`           | RDS master password                |
| `APP_KEY`               | Laravel APP_KEY (base64:...)       |

## Pipeline stages

1. **Security** — Checkov + tfsec + Trivy scan (all must pass)
2. **Validate** — `terraform fmt` check + `terraform validate`
3. **Plan** — generates plan, posts as PR comment
4. **Apply** — runs on `main` branch push only, requires manual approval via GitHub Environments

## Security checks enforced

| Tool     | What it checks                                      |
|----------|-----------------------------------------------------|
| Checkov  | 20+ AWS best-practice rules (encryption, logging…)  |
| tfsec    | Terraform-specific misconfigurations                |
| Trivy    | HIGH/CRITICAL misconfigs + secrets in IaC files     |

Results appear in GitHub → Security → Code scanning alerts.

## Useful commands

```bash
# Format all files
terraform fmt -recursive

# See what will be destroyed (danger check)
terraform plan | grep "will be destroyed"

# Target a single module
terraform plan -target=module.ecs
terraform apply -target=module.ecs

# View outputs
terraform output alb_dns_name
```
..