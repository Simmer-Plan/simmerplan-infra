# Secrets Rotation

## Trigger

- Scheduled rotation (quarterly for OAuth credentials)
- Suspected credential exposure — rotate immediately, then investigate
- A team member with secret access departs

## Background

Secrets live in Secrets Manager as `simmerplan-<name>-<env>` (currently
`simmerplan-google-oauth-<env>`). Terraform manages only the container —
values never pass through Terraform state. Rotation is
[`ansible/playbooks/rotate_secrets.yml`](../../ansible/playbooks/rotate_secrets.yml).

## Procedure

1. Obtain the new credential at the source (e.g. Google Cloud Console →
   Credentials → rotate the OAuth client secret).

2. Write the new value; the old one automatically moves to the `AWSPREVIOUS`
   stage:

   ```bash
   cd ansible
   ansible-playbook playbooks/rotate_secrets.yml \
     -e environment=<env> \
     -e secret_name=simmerplan-google-oauth-<env> \
     -e secret_value='{"client_id":"…","client_secret":"…"}'
   ```

3. Bounce consumers if they cache the value (Lambda picks up secrets per
   cold start; force one with a no-op description update):

   ```bash
   aws lambda update-function-configuration \
     --function-name simmerplan-api-<env> --description "secret rotation $(date -u +%F)"
   ```

4. Revoke the old credential at the source **after** verification.

## Rollback

The previous value stays on `AWSPREVIOUS`:

```bash
aws secretsmanager get-secret-value --secret-id simmerplan-google-oauth-<env> \
  --version-stage AWSPREVIOUS
```

Re-put it with the playbook if the new credential is bad.

## Verification

- `aws secretsmanager describe-secret --secret-id simmerplan-google-oauth-<env>`
  shows a new `AWSCURRENT` version ID
- Auth flow works end-to-end (sign-in via Google in the target environment)
- No spike on `simmerplan-api-<env>-errors` after the rotation
