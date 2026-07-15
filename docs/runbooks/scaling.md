# Scaling Up / Down

## Trigger

- Sustained Lambda throttles (`Throttles` metric > 0 across multiple periods)
- p95 API latency degrading under load
- The `simmerplan-<env>-throttled` DynamoDB alarm fires repeatedly (see
  [incident-response.md](incident-response.md) for the acute case)

## Background

- **Lambda** runs with unreserved account concurrency by default (1000 shared
  per account/region). Nothing needs pre-scaling until traffic justifies it.
- **DynamoDB** is `PAY_PER_REQUEST` — it scales itself; there is no capacity to
  provision. What matters is *monitoring* the thresholds below, not scaling.

## Procedure — Lambda

1. Check current throttling and concurrency:

   ```bash
   aws lambda get-function --function-name simmerplan-api-<env> \
     --query Concurrency
   aws cloudwatch get-metric-statistics --namespace AWS/Lambda \
     --metric-name Throttles --statistics Sum --period 300 \
     --start-time "$(date -u -d '-3 hours' +%FT%TZ)" --end-time "$(date -u +%FT%TZ)" \
     --dimensions Name=FunctionName,Value=simmerplan-api-<env>
   ```

2. To guarantee capacity for the API function (also caps it — both directions):

   ```bash
   aws lambda put-function-concurrency \
     --function-name simmerplan-api-<env> --reserved-concurrent-executions 100
   ```

3. To remove the cap: `aws lambda delete-function-concurrency --function-name simmerplan-api-<env>`

4. Memory/timeout changes go through Terraform (`memory_size`, `timeout` on the
   `lambda_api` module call) — PR, plan, merge; never the console.

## Procedure — DynamoDB (monitoring thresholds)

`PAY_PER_REQUEST` tables throttle only on sudden spikes beyond double the
previous peak. Watch, don't provision:

- `ThrottledRequests` > 0 sustained → alarm already exists (`simmerplan-<env>-throttled`)
- `ConsumedReadCapacityUnits` / `ConsumedWriteCapacityUnits` trending near
  2× the prior peak → expect adaptive scaling lag on the next spike

If a predictable large spike is coming (launch, import), pre-warm by ramping
synthetic traffic gradually, or evaluate a temporary switch to provisioned
capacity via the `billing_mode` module variable (PR + plan; requires care —
switching modes is limited to once per 24h).

## Verification

- `Throttles` and `ThrottledRequests` return to 0 over the next hour
- `aws lambda get-function --function-name simmerplan-api-<env> --query Concurrency`
  reflects the intended setting
- No new alarm notifications on the `simmerplan-alerts-<env>` SNS topic
