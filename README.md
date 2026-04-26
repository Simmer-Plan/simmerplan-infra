# simmerplan-infra

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

Infrastructure and configuration management for Simmerplan.

## Setup

run `setup.sh` **NOTE** this script currently assumes installing on Arch Linux

## Next steps

  1. Configure the management account AWS profile:
       aws configure --profile simmerplan-management
     (credentials for the AWS Organizations management account)

  2. Copy and populate tfvars for each account workspace:
       cp terraform/accounts/management/terraform.tfvars.example terraform/accounts/management/terraform.tfvars
       cp terraform/accounts/sandbox/terraform.tfvars.example    terraform/accounts/sandbox/terraform.tfvars
       cp terraform/accounts/prod/terraform.tfvars.example       terraform/accounts/prod/terraform.tfvars
     Fill in the real AWS account IDs for management, sandbox, and prod.

  3. Run bootstrap (once, against the management account):
       cd terraform/bootstrap && terraform init && terraform apply

  4. Initialise a workspace (sandbox example):
       cd terraform/accounts/sandbox && terraform init \
         -backend-config="bucket=<state-bucket>" \
         -backend-config="dynamodb_table=<lock-table>" \
         -backend-config="region=ca-central-1"

### Prerequisites

- Terraform >= 1.0
- Ansible >= 2.x
- AWS CLI configured with appropriate credentials

### Bootstrap

See [terraform/bootstrap/](terraform/bootstrap/) for initial account bootstrap instructions.

### Environments

- **sandbox** — auto-applies on merge to `develop`
- **prod** — manual approval gate on merge to `main`

## Branch Strategy

- `main` → prod deploys (manual approval gate)
- `develop` → sandbox deploys (auto-apply on merge)
- `feature/*` → PRs into `develop`