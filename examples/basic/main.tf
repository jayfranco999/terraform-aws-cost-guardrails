# Minimal working example. Cost Anomaly Detection is only available in us-east-1,
# so pin the provider there even if the rest of your estate lives elsewhere.
provider "aws" {
  region = "us-east-1"
}

module "cost_guardrails" {
  source = "../../"

  name               = "acme-prod"
  monthly_budget_usd = 2000
  alert_emails       = ["platform@example.com"]

  # Alert on spend already incurred, then once more on the forecast.
  actual_thresholds_percent  = [50, 80, 100]
  forecast_threshold_percent = 90

  anomaly_threshold_usd = 100

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

output "cost_alerts_topic" {
  value = module.cost_guardrails.sns_topic_arn
}
