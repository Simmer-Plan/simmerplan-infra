# Rollback

Two distinct cases: **infrastructure** (Terraform) and **application code**
(Lambda package deployed by Ansible).

## Case 1 — Roll back a Terraform change

### Trigger

A merged infrastructure change is causing damage and reverting is faster or
safer than fixing forward.

### Procedure (preferred: revert the commit)

1. Revert in git — never edit state by hand:

   ```bash
   git revert <bad-commit>
   git push origin development   # sandbox auto-applies via CI
   ```

   For prod: PR the revert to `main`; the apply waits on the approval gate.

2. CI runs `terraform apply` and converges the account back.

### Procedure (state file recovery — corruption/bad migration only)

The state bucket is versioned. To restore a previous state version:

```bash
BUCKET=simmerplan-terraform-state-<management-account-id>
KEY=<env>/terraform.tfstate
aws s3api list-object-versions --bucket "$BUCKET" --prefix "$KEY" \
  --query 'Versions[].{id:VersionId,when:LastModified,current:IsLatest}' --output table
aws s3api get-object --bucket "$BUCKET" --key "$KEY" \
  --version-id <version-id> /tmp/state-rollback.tfstate
# Inspect it, then:
aws s3 cp /tmp/state-rollback.tfstate "s3://$BUCKET/$KEY"
```

Then run `terraform plan` immediately — it must reconcile cleanly against real
infrastructure before anyone applies anything.

### Verification

- `terraform plan` reports `No changes` (or only the expected differences)
- `ansible-playbook playbooks/health_check.yml -e environment=<env>` passes

## Case 2 — Roll back Lambda code

### Trigger

A bad application deploy: error rate spike right after `ansible_deploy` ran
(the `simmerplan-api-<env>-errors` alarm firing is the usual tell).

### Procedure

Terraform ignores Lambda code changes by design (`ignore_changes` on the
package — Ansible owns deploys), so code rollback is an AWS operation:

1. List versions and pick the last good one:

   ```bash
   aws lambda list-versions-by-function --function-name simmerplan-api-<env> \
     --query 'Versions[].{v:Version,when:LastModified,sha:CodeSha256}' --output table
   ```

2. Re-point `$LATEST` at the prior package by re-deploying that version's code:

   ```bash
   aws lambda update-function-code --function-name simmerplan-api-<env> \
     --s3-bucket <artifact-bucket> --s3-key <last-good-package>   # if deploys use S3
   ```

   or re-run the Ansible deploy from the last good app commit:

   ```bash
   cd simmerplan-app && git checkout <last-good-sha> && cd ../simmerplan-infra/ansible
   ansible-playbook playbooks/deploy_lambda.yml -e environment=<env>
   ```

### Verification

- `aws lambda get-function --function-name simmerplan-api-<env> --query Configuration.CodeSha256`
  matches the last good sha
- Error alarm returns to OK; `health_check.yml` passes
