# Terraform Bootstrap

Run this once manually to create the S3 bucket and DynamoDB table used as
the remote state backend for all other Terraform workspaces.

## Prerequisites

- AWS CLI authenticated to the management account
- Terraform >= 1.0

## Steps

1. Copy the example vars file and fill in values:

   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Initialize and apply (local state is fine for bootstrap):

   ```bash
   terraform init
   terraform apply
   ```

3. Note the outputs — you will use them as `-backend-config` arguments when
   initializing the sandbox and prod workspaces.

## After Bootstrap

Initialize sandbox:

```bash
cd ../accounts/sandbox
terraform init \
  -backend-config="bucket=<state-bucket>" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=<lock-table>"
```

Repeat for prod.
