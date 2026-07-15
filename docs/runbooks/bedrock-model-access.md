# Bedrock Model Access

## Trigger

- Bootstrapping a new account (first deploy)
- The AI suggestion feature needs a model family not yet enabled
- Lambda logs show `AccessDeniedException` from `bedrock:InvokeModel` despite
  correct IAM (the IAM policy exists — module `bedrock` — but the *account*
  has not been granted the model)

## Background

Bedrock model access is a **per-account, one-time console action** — there is
no API or Terraform resource for it. IAM invoke permissions are already
managed by Terraform (`simmerplan-bedrock-invoke-<env>` policy, attached to
the API Lambda role). The verification playbook is
[`ansible/playbooks/enable_bedrock.yml`](../../ansible/playbooks/enable_bedrock.yml).

## Procedure

1. Check current access:

   ```bash
   cd ansible
   ansible-playbook playbooks/enable_bedrock.yml -e environment=<env>
   ```

   If models are listed, access already exists — stop here.

2. Otherwise, in the **target account** console:
   *Amazon Bedrock → Model access → Manage model access → tick the Anthropic
   models → Submit.* Access typically activates within minutes.

3. If new model IDs fall outside the IAM policy prefixes, extend
   `allowed_model_prefixes` on the `bedrock` module call and apply through CI.

## Verification

- `enable_bedrock.yml` lists the expected model IDs
- A live invoke succeeds from the account:

  ```bash
  aws bedrock-runtime invoke-model \
    --model-id anthropic.claude-3-5-haiku-20241022-v1:0 \
    --body '{"anthropic_version":"bedrock-2023-05-31","max_tokens":10,"messages":[{"role":"user","content":"ping"}]}' \
    --cli-binary-format raw-in-base64-out /tmp/bedrock-test.json && cat /tmp/bedrock-test.json
  ```
