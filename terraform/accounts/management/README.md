# Management Account

Provisions the AWS Organizations structure (OUs and member accounts) and the GitHub Actions
OIDC provider that enables keyless AWS authentication for CI/CD.

**Run this workspace once, manually, after bootstrap.** It must be applied before the sandbox
and prod workspaces can be initialised, because those workspaces rely on the member accounts
that Organizations creates here.

## What gets created

| Resource | Description |
|---|---|
| `aws_organizations_organization` | AWS Organization with all features + SCP support |
| `aws_organizations_organizational_unit` (×2) | `sandbox` and `prod` OUs under the root |
| `aws_organizations_account` (×2) | `simmerplan-sandbox` and `simmerplan-prod` member accounts |
| `aws_iam_openid_connect_provider` | GitHub Actions OIDC provider (`token.actions.githubusercontent.com`) |
| `aws_iam_role` (`TerraformDeployRole`) | IAM role assumable by GitHub Actions via OIDC |

## Prerequisites

- Bootstrap has been run and its S3 bucket name output is available —
  see `terraform/bootstrap/README.md`
- AWS CLI authenticated to the management account (`simmerplan-management` profile)
- Terraform >= 1.0

## Steps

### 1. Configure variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and fill in real values:

| Variable | Description |
|---|---|
| `account_id` | Management AWS account ID (12 digits) |
| `github_org` | GitHub organisation name (e.g. `Simmer-Plan`) |
| `github_repo` | Repository name without the org prefix (e.g. `simmerplan-infra`) |
| `sandbox_account_email` | Unique root email for the sandbox member account |
| `prod_account_email` | Unique root email for the prod member account |

> **Note:** Each AWS account requires a globally unique email address. If the sandbox and prod
> accounts have already been created manually, use the emails they were created with and follow
> the import steps below before applying.

### 2. Initialise the backend

Use the bucket and table names from the bootstrap outputs:

```bash
terraform init \
  -backend-config="bucket=<state-bucket>" \
  -backend-config="region=ca-central-1" \
  -backend-config="use_lockfile=true"
```

### 3. Import existing resources (if applicable)

Skip this step if the AWS Organization and member accounts do not exist yet.

If the Organization was already created:

```bash
terraform import module.organizations.aws_organizations_organization.this <organization-id>
```

If the sandbox and prod accounts already exist in the Organization:

```bash
terraform import module.organizations.aws_organizations_account.sandbox <sandbox-account-id>
terraform import module.organizations.aws_organizations_account.prod    <prod-account-id>
```

If the OIDC provider was already created manually:

```bash
terraform import module.oidc.aws_iam_openid_connect_provider.github \
  arn:aws:iam::<management-account-id>:oidc-provider/token.actions.githubusercontent.com
```

### 4. Plan

Review what Terraform intends to create or modify before applying:

```bash
terraform plan -var-file="terraform.tfvars"
```

Key things to verify in the plan output:

- Organizations org, OUs, and accounts are being created (or show as already imported)
- The OIDC provider URL is `https://token.actions.githubusercontent.com`
- `TerraformDeployRole` trust policy references your GitHub org and repo

### 5. Apply

```bash
terraform apply -var-file="terraform.tfvars"
```

Account creation can take 1–2 minutes per account. Terraform will wait.

### 6. Validate

Confirm the following in the AWS console (management account):

- **IAM → Identity providers** — `token.actions.githubusercontent.com` is listed
- **IAM → Roles → TerraformDeployRole** — exists; trust policy shows the correct GitHub repo
- **AWS Organizations** — `sandbox` and `prod` OUs are visible under the root; member accounts
  are assigned to their respective OUs

## Outputs

After a successful apply, note these output values for use in later steps:

```bash
terraform output
```

| Output | Used by |
|---|---|
| `module.oidc.role_arn` | GitHub Actions workflow `role-to-assume` input (SIM-34) |
| `module.oidc.oidc_provider_arn` | Reference if manually granting additional roles |
| `module.organizations.sandbox_account_id` | `terraform.tfvars` in `accounts/sandbox` |
| `module.organizations.prod_account_id` | `terraform.tfvars` in `accounts/prod` |

## Next steps

1. Record the `sandbox_account_id` and `prod_account_id` outputs, then initialise the sandbox
   and prod workspaces following the same init pattern (backend-config bucket from bootstrap,
   `use_lockfile=true`).
2. Add `module.oidc.role_arn` to the GitHub Actions workflow configuration (SIM-34).
