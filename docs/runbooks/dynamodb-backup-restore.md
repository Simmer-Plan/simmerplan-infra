# DynamoDB Backup / Restore (PITR)

## Trigger

- Bad data written at a known time (application bug, bad migration/seed)
- Accidental bulk deletion
- Table corruption of any kind in prod

## Background

- **prod** (`simmerplan-prod`): PITR enabled by Terraform — restore to any
  second in the last 35 days. Deletion protection is also on.
- **sandbox** (`simmerplan-sandbox`): PITR intentionally off; recovery is
  re-seeding (`seed_dynamo.yml`), not restore.

PITR restores **to a new table** — never in place.

## Identify the restore point

Find when the bad write happened; restore to just before it:

```bash
aws dynamodb describe-continuous-backups --table-name simmerplan-prod \
  --query 'ContinuousBackupsDescription.PointInTimeRecoveryDescription'
# EarliestRestorableDateTime / LatestRestorableDateTime bound your window.
```

Correlate with the app: CloudWatch Logs Insights on
`/aws/lambda/simmerplan-api-prod` around the suspected time, or the diff-log
records (GSI1) which timestamp every entity change.

## Procedure

1. Restore to a side table:

   ```bash
   aws dynamodb restore-table-to-point-in-time \
     --source-table-name simmerplan-prod \
     --target-table-name simmerplan-prod-restore-$(date +%Y%m%d) \
     --restore-date-time "2026-07-15T03:00:00Z"
   ```

2. Wait for `ACTIVE`, then compare the restored data against the live table
   for the affected keys before touching anything:

   ```bash
   aws dynamodb wait table-exists --table-name simmerplan-prod-restore-<date>
   ```

3. Copy corrected items back to the live table (targeted `put-item` from the
   restored table — prefer surgical fixes over wholesale table swaps; a swap
   loses writes made after the restore point).

4. If a full swap is genuinely required: restored tables come back **without**
   PITR/deletion protection — re-point the application only after re-enabling
   both, and update Terraform state accordingly. This path needs a planned
   maintenance window; treat it as a last resort.

5. Delete the side table when done (it bills as a normal table):

   ```bash
   aws dynamodb delete-table --table-name simmerplan-prod-restore-<date>
   ```

## Verification

- Affected items read back correct values via the API (spot-check with
  `aws dynamodb get-item`)
- `health_check.yml` passes against prod
- PITR still enabled on the live table (`describe-continuous-backups`)

## Sandbox note (SIM-36 AC)

The procedure above was designed against sandbox by temporarily enabling PITR
(`point_in_time_recovery = true` on the module call, apply, test, revert) —
repeat that drill after any significant schema change.
