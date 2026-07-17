# Simmerplan Ops Runbooks

Standard operating procedures for the Simmerplan AWS infrastructure (SIM-36).
Every runbook follows the same shape: **trigger condition → procedure → verification**.

| Runbook | Covers |
|---|---|
| [scaling.md](scaling.md) | Lambda concurrency, DynamoDB on-demand monitoring thresholds |
| [rollback.md](rollback.md) | Terraform state rollback, Lambda code revert |
| [secrets-rotation.md](secrets-rotation.md) | Secrets Manager rotation via `rotate_secrets.yml` |
| [dynamodb-backup-restore.md](dynamodb-backup-restore.md) | PITR restore procedure (prod) |
| [bedrock-model-access.md](bedrock-model-access.md) | Enabling foundation models in an account |
| [incident-response.md](incident-response.md) | First steps for Lambda errors, API 5xx, DynamoDB throttling |

Conventions used throughout:

- `<env>` is `sandbox` or `prod`; resources are named `simmerplan-<resource>-<env>`
  (table: `simmerplan-<env>`). Region is `ca-central-1`.
- CLI examples assume credentials for the target account — locally via
  `AWS_PROFILE`, in CI via OIDC. See CLAUDE.md → Authentication.
- Ansible playbooks are run from the `ansible/` directory.
