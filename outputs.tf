output "sns_topic_arn" {
  description = "ARN of the SNS topic every alert publishes to. Subscribe Slack or PagerDuty here."
  value       = aws_sns_topic.this.arn
}

output "budget_name" {
  description = "Name of the monthly cost budget."
  value       = aws_budgets_budget.monthly.name
}

output "anomaly_monitor_arn" {
  description = "ARN of the cost anomaly monitor, or null when anomaly detection is disabled."
  value       = try(aws_ce_anomaly_monitor.this[0].arn, null)
}

output "pending_email_confirmations" {
  description = "Reminder: SNS email subscriptions stay Pending until each recipient clicks the confirmation link. Until then they get nothing."
  value       = var.alert_emails
}
