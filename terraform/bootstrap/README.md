# Terraform Bootstrap

Run this once manually to create the S3 bucket used as the remote state
backend for all other Terraform workspaces. Locking uses S3 native lock
files (`use_lockfile = true`) — no DynamoDB table required.

## Prerequisites

- AWS CLI authenticated to the management account
- A profile the **Terraform AWS provider** can read — see
  [Authentication](../../CLAUDE.md#authentication-local-runs). A profile using the
  `aws login` session flow will not work.
- Terraform >= 1.0

## Steps

1. Copy the example vars file (values are already correct for most cases):

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Initialize and apply (local state is intentional for bootstrap):

   ```bash
   terraform init
   terraform apply
   ```

   The S3 bucket name is derived automatically from the current AWS account ID
   (`simmerplan-terraform-state-<account-id>`), so no bucket name variable is needed.

3. Note the `state_bucket_name` output — use it as a `-backend-config` argument
   when initializing every other workspace.

Bootstrap runs **once, against the management account only**. It creates a single
bucket that holds the state for all three workspaces, separated by key:

| Workspace | State key |
|---|---|
| `accounts/management` | `management/terraform.tfstate` |
| `accounts/sandbox` | `sandbox/terraform.tfstate` |
| `accounts/prod` | `prod/terraform.tfstate` |

Bootstrap itself keeps local state, since the bucket cannot store the state that
creates it.

## After Bootstrap

Initialize sandbox:

```bash
cd ../accounts/sandbox
terraform init \
  -backend-config="bucket=<state_bucket_name output>" \
  -backend-config="region=ca-central-1" \
  -backend-config="use_lockfile=true" \
  -backend-config="profile=<terraform-readable profile>"
```

Repeat for prod and management, changing only the directory.

Omit the `profile` line in CI: GitHub Actions authenticates via OIDC and has no
named profile. The S3 backend does **not** read the `aws_profile` variable — it is
configured entirely through `-backend-config`, which is why the profile is passed
here rather than committed to `backend.tf`.
