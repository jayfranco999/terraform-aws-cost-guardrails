# terraform-aws-cost-guardrails

A small Terraform module that puts a monthly cost budget, forecast alerting and AWS Cost
Anomaly Detection behind a single SNS topic.

Validated with `terraform validate` against AWS provider **6.73.0** on Terraform 1.x, and
formatted with `terraform fmt`. The constraint is `>= 5.0`; 5.x is not separately tested.

## Why this exists

Most AWS accounts find out about a cost problem when the invoice arrives. The usual fix is
a budget alert at 100 percent of spend, which tells you the money is already gone.

This module does three things instead:

1. **Alerts on actual spend** at thresholds you choose, 50/80/100 percent by default.
2. **Alerts on forecast spend**, which is the one that gives you time to react. AWS projects
   where the month is heading and warns before you arrive.
3. **Watches for anomalies per service**, so a single runaway resource is caught mid-month
   rather than being hidden inside an otherwise normal total.

All three publish to one SNS topic, so you wire Slack, PagerDuty or email once.

## Usage

```hcl
module "cost_guardrails" {
  source = "github.com/jayfranco999/terraform-aws-cost-guardrails"

  name               = "acme-prod"
  monthly_budget_usd = 2000
  alert_emails       = ["platform@example.com"]

  actual_thresholds_percent  = [50, 80, 100]
  forecast_threshold_percent = 90
  anomaly_threshold_usd      = 100

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}
```

A complete working example is in [`examples/basic`](examples/basic).

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | string | required | Prefix for every created resource. 3 to 32 chars, lowercase, digits, hyphens. |
| `monthly_budget_usd` | number | required | Monthly budget in USD. Must be greater than zero. |
| `alert_emails` | list(string) | required | Recipients. At least one, each validated as an address. |
| `actual_thresholds_percent` | list(number) | `[50, 80, 100]` | Percentages of budget to alert on for spend already incurred. |
| `forecast_threshold_percent` | number | `100` | Percentage to alert on for forecast spend. `null` disables. |
| `anomaly_threshold_usd` | number | `50` | Minimum USD impact before an anomaly alerts. |
| `enable_anomaly_detection` | bool | `true` | Create the anomaly monitor and subscription. |
| `tags` | map(string) | `{}` | Tags applied to every taggable resource. |

## Outputs

| Name | Description |
|---|---|
| `sns_topic_arn` | Topic every alert publishes to. Add Slack or PagerDuty here. |
| `budget_name` | Name of the monthly budget. |
| `anomaly_monitor_arn` | Monitor ARN, or `null` when anomaly detection is off. |
| `pending_email_confirmations` | The addresses that still need to click confirm. |

## Three things that bite people, handled here

**SNS topic policy.** AWS Budgets and Cost Anomaly Detection publish from their own service
principals (`budgets.amazonaws.com`, `costalerts.amazonaws.com`). Without an explicit topic
policy the alarms are created successfully and then silently never deliver. That is worse
than having no alarm, because you believe you are covered. The policy is in `main.tf` and
the alarms `depends_on` it so ordering cannot race.

**Email subscriptions start as Pending.** SNS email endpoints deliver nothing until each
recipient clicks the confirmation link. The `pending_email_confirmations` output exists to
stop that being forgotten on day one.

**Region.** Cost Anomaly Detection is only available in `us-east-1`. The example pins the
provider there. Billing data is account-wide regardless of where the rest of your estate
runs, so this is not a limitation on what gets monitored.

## Notes on thresholds

`anomaly_threshold_usd` defaults to 50 rather than 0 deliberately. An anomaly monitor with
no floor fires on rounding noise, and an alert channel that cries wolf gets muted within a
week. Set it to roughly the smallest surprise you would actually act on.

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.5.0 |
| aws provider | >= 5.0 |

## Licence

MIT. See [LICENSE](LICENSE).
