# simmerplan-infra

Infrastructure and configuration management for Simmerplan — a meal planning app. Terraform IaC + Ansible automation targeting AWS, multi-account setup (management, sandbox, prod).

License: Apache 2.0. Copyright 2026 Dave LeBlanc.

---

## Repository layout

```
terraform/
  bootstrap/          # One-time remote state setup (run manually against management account)
  modules/            # Reusable AWS service modules (14 modules — see below)
  accounts/
    management/       # AWS Organizations management account
    sandbox/          # Dev/test environment — auto-deploy on develop branch
    prod/             # Production — manual approval gate on main branch
ansible/
  playbooks/          # Deployment and operational playbooks
  roles/              # Reusable roles (common, lambda, dynamodb)
  inventory/          # *.ini files are gitignored; *.example.ini committed
.github/workflows/    # CI/CD stubs (implementation tracked in SIM-25)
```

---

## AWS modules

| Module | Purpose |
|---|---|
| `lambda` | Lambda function definitions |
| `api_gateway` | HTTP API Gateway |
| `dynamodb` | Single-table DynamoDB (simmerplan-\<env\>) |
| `cognito` | User pool + identity pool |
| `s3` | Buckets |
| `cloudfront` | CDN distribution |
| `acm` | TLS certificates |
| `route53` | DNS (simmerplan.com) |
| `bedrock` | AI/ML meal suggestions |
| `secrets` | Secrets Manager |
| `eventbridge` | Event bus |
| `cloudwatch` | Monitoring and alarms |
| `oidc` | GitHub Actions OIDC provider (keyless CI auth) |
| `organizations` | AWS Organizations / account management |

---

## Environments

| Environment | Account | Branch | Deploy trigger |
|---|---|---|---|
| sandbox | AWS sandbox | `development` | Auto on merge |
| prod | AWS prod | `main` | Manual approval gate |

AWS region: **ca-central-1**

---

## Resource naming

```
simmerplan-<resource-type>-<env>
```

Examples: `simmerplan-sandbox`, `simmerplan-prod`, `simmerplan-api-sandbox`

---

## Remote state backend

S3 with native lock files (`use_lockfile = true`) and encryption. One bucket in the management
account (`simmerplan-terraform-state-<management-account-id>`) holds the state for all three
workspaces, separated by key: `management/`, `sandbox/`, and `prod/terraform.tfstate`.

Bootstrap must be run **once manually** against the management account before any account
workspaces can be initialised:

```bash
cd terraform/bootstrap
terraform init
terraform apply
```

The bootstrap outputs the bucket name; pass it as a `-backend-config` argument when running `terraform init` in any account workspace. No DynamoDB table is required.

---

## Authentication (local runs)

The Terraform AWS provider reads credentials with the Go SDK, which **cannot** use the
AWS CLI's `aws login` session flow (`login_session` in `~/.aws/config`). A profile that
works with `aws sts get-caller-identity` may still fail under Terraform.

Bridge it with a `credential_process` profile that delegates to the CLI:

```ini
# ~/.aws/config
[profile simmerplan-management-tf]
region = ca-central-1
credential_process = aws configure export-credentials --profile simmerplan-management --format process
```

Pass that profile two separate ways — they are **not** interchangeable:

| Consumer | How it gets the profile |
|---|---|
| AWS provider | `aws_profile` variable, set in `terraform.tfvars` |
| S3 backend | `-backend-config="profile=..."` at `terraform init` |

Both are omitted in CI, where GitHub Actions authenticates via OIDC and no named profile
exists. That is why neither is hardcoded in `backend.tf` or a `provider` block.

## Common Terraform commands

```bash
# Initialise a workspace (sandbox example)
cd terraform/accounts/sandbox
terraform init \
  -backend-config="bucket=<state-bucket>" \
  -backend-config="region=ca-central-1" \
  -backend-config="use_lockfile=true" \
  -backend-config="profile=simmerplan-management-tf"   # omit in CI

# Plan / apply
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

`*.tfvars` is gitignored. Copy `terraform.tfvars.example` and populate locally.

---

## Ansible playbooks

| Playbook | Purpose |
|---|---|
| `deploy_lambda.yml` | Deploy Lambda function packages |
| `deploy_static.yml` | Deploy static assets to S3/CloudFront |
| `seed_dynamo.yml` | First-deploy DynamoDB seeding (calls scaffold-db.ts from simmerplan-app) |
| `rotate_secrets.yml` | Rotate Secrets Manager secrets |
| `health_check.yml` | Post-deploy health verification |
| `enable_bedrock.yml` | Enable Bedrock model access in an account |

---

## DynamoDB schema

Single-table design. Table name driven by `DYNAMODB_TABLE` env var.

| Key | Type | Description |
|---|---|---|
| `PK` | String | Partition key |
| `SK` | String | Sort key |
| `GSI1PK` / `GSI1SK` | String | Household-scoped diff log queries |
| `GSI2PK` / `GSI2SK` | String | Recipe ingredient lookups |

Billing: `PAY_PER_REQUEST`. Prod only: deletion protection + point-in-time recovery enabled.

Schema design: SIM-6. Scaffold script: `scripts/scaffold-db.ts` in simmerplan-app (SIM-30).

---

## CI/CD (GitHub Actions)

Workflows are stubs pending SIM-25:

- `terraform_plan.yml` — triggered on PRs to `main`/`develop` when `terraform/` changes
- `terraform_apply.yml` — triggered on push to `main`/`develop` when `terraform/` changes
- `ansible_deploy.yml` — triggered on push to `main`/`develop` when `ansible/` changes

GitHub Actions authenticates to AWS via OIDC (no long-lived credentials) using the `oidc` module.

---

## Security scanning

`.tfsec/` config is present. Run `tfsec .` from the repo root before opening PRs.

---

## License headers

Add the Apache 2.0 header to the top of **all non-trivial source files** (`.tf`, `.yml` playbooks). Omit from JSON and generated files.

```
Copyright 2026 Dave LeBlanc

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

---

## Branch strategy

```
main        → prod (manual approval)
development → sandbox (auto-apply)
feature/*   → PR into development
```

Branch protection is on `main`.

---

## Linear issues

| Issue | Title | Status |
|---|---|---|
| SIM-5 | Define overall system architecture | Done |
| SIM-6 | Design database schema | Done |
| SIM-23 | Investigation — system architecture options | Done |
| SIM-24 | IaC planning — infrastructure design and resource mapping | Done |
| SIM-28 | Create Git repository and project structure | Done |
| SIM-30 | Create DynamoDB scaffold script (in simmerplan-app) | Done |
| SIM-25 | IaC writing — provision all environments (parent) | Todo |
| SIM-31 | └ Bootstrap remote state backend | Done |
| SIM-32 | └ Wire up management account + OIDC provider | In Review |
| SIM-33 | └ Wire up and validate sandbox environment | Todo |
| SIM-34 | └ Implement GitHub Actions CI/CD workflows | Todo |
| SIM-35 | └ Wire up and provision prod environment | Todo |
| SIM-36 | └ Write ops runbooks | Backlog |

All issues are in Phase 1 — Foundation milestone.
