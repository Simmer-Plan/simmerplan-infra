# Incident Response Checklist

First steps for the three alarmed failure modes. All three alarms notify the
`simmerplan-alerts-<env>` SNS topic.

## Universal first five minutes

1. Which alarm, which environment, since when?

   ```bash
   aws cloudwatch describe-alarms --state-value ALARM \
     --query 'MetricAlarms[].{name:AlarmName,since:StateUpdatedTimestamp,reason:StateReason}'
   ```

2. What changed recently? Check the last `terraform_apply` / `ansible_deploy`
   runs (`gh run list --limit 5`) and recent merges to `development`/`main`.
   **If the incident started right after a deploy, go straight to
   [rollback.md](rollback.md).**

3. Is it user-visible? `curl -s -o /dev/null -w '%{http_code}' https://<api-endpoint>/health`

## `simmerplan-api-<env>-errors` (Lambda errors)

1. Pull the actual errors:

   ```bash
   aws logs tail /aws/lambda/simmerplan-api-<env> --since 30m --filter-pattern ERROR
   ```

2. Classify:
   - **Code exception** after a deploy → [rollback.md](rollback.md) Case 2
   - **AccessDenied on DynamoDB/Bedrock** → recent IAM change; revert it
     ([rollback.md](rollback.md) Case 1) or fix the policy forward
   - **Timeouts** → check downstream: DynamoDB throttling (below), or raise
     `timeout`/`memory_size` via Terraform if load-driven
3. Verify: alarm back to OK, error count zero over two consecutive periods.

## `simmerplan-api-<env>-5xx` (API Gateway 5xx)

1. Access logs show the failing routes:

   ```bash
   aws logs tail /aws/apigateway/simmerplan-api-<env> --since 30m
   ```

2. Classify:
   - 5xx **with** Lambda errors → it is the Lambda incident above
   - 5xx **without** Lambda errors → integration layer: recent API Gateway
     change, permission drift (`aws_lambda_permission`), or throttling at the
     stage's rate limits (integration errors appear in the access log's
     `integrationErr` field)
3. Verify: `/health` returns 200; 5xx metric flat for 15 minutes.

## `simmerplan-<env>-throttled` (DynamoDB throttling)

1. Which operations are throttled?

   ```bash
   aws cloudwatch get-metric-statistics --namespace AWS/DynamoDB \
     --metric-name ThrottledRequests --statistics Sum --period 300 \
     --start-time "$(date -u -d '-2 hours' +%FT%TZ)" --end-time "$(date -u +%FT%TZ)" \
     --dimensions Name=TableName,Value=simmerplan-<env>
   ```

2. On-demand tables throttle on spikes >2× the previous peak or on hot keys:
   - **Traffic spike** — usually self-resolves as adaptive capacity kicks in;
     confirm the spike is legitimate traffic, not a runaway client loop
     (check API access logs for a single hammering caller)
   - **Hot partition** — a single PK receiving disproportionate writes (the
     diff-log pattern makes household PKs the likely suspects); needs an
     application-level fix, file it against Phase 2
3. Verify: `ThrottledRequests` back to 0; API latency normal.

## Escalation

Single-operator project: if a prod incident exceeds 30 minutes without a safe
rollback path, stop the bleeding first — API Gateway stage throttle to 0 puts
prod in maintenance rather than serving corrupt data:

```bash
aws apigatewayv2 update-stage --api-id <api-id> --stage-name '$default' \
  --default-route-settings ThrottlingRateLimit=0,ThrottlingBurstLimit=0
```

Restore by re-applying Terraform (the stage settings are managed).
