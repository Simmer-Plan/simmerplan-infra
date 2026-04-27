# Terraform Bootstrap

Run this once manually to create the S3 bucket used as the remote state
backend for all other Terraform workspaces. Locking uses S3 native lock
files (`use_lockfile = true`) — no DynamoDB table required.

## Prerequisites

- AWS CLI authenticated to the management account
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
   when initializing the sandbox and prod workspaces. Run bootstrap once per
   sub-account (sandbox, then prod) — the management account uses local state
   only and is never bootstrapped.

## After Bootstrap

Initialize sandbox:

```bash
cd ../accounts/sandbox
terraform init \
  -backend-config="bucket=<state_bucket_name output>" \
  -backend-config="region=ca-central-1" \
  -backend-config="use_lockfile=true"
```

Repeat for prod.
