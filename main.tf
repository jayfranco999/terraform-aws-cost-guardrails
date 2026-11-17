# Cost guardrails: a monthly budget with actual and forecast alerts, plus optional
# anomaly detection, all reporting to one SNS topic.
#
# Why forecast alerts matter: an ACTUAL alert at 100 percent tells you the money is
# already gone. A FORECAST alert tells you while you can still do something about it.

locals {
  # Budget notifications need a stable key per threshold so a reordered list does not
  # destroy and recreate unrelated notifications.
  actual_thresholds = { for t in var.actual_thresholds_percent : tostring(t) => t }
}

resource "aws_sns_topic" "this" {
  name = "${var.name}-cost-alerts"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  for_each = toset(var.alert_emails)

  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = each.value
}

# AWS Budgets and Cost Anomaly Detection publish from their own service principals, so
# the topic policy has to let them in explicitly. Without this the alarms are created
# successfully and then silently never deliver, which is the worst possible outcome.
data "aws_iam_policy_document" "topic" {
  statement {
    sid    = "AllowCostServicesToPublish"
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = [
        "budgets.amazonaws.com",
        "costalerts.amazonaws.com",
      ]
    }

    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.this.arn]
  }
}

resource "aws_sns_topic_policy" "this" {
  arn    = aws_sns_topic.this.arn
  policy = data.aws_iam_policy_document.topic.json
}

resource "aws_budgets_budget" "monthly" {
  name         = "${var.name}-monthly-cost"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = local.actual_thresholds

    content {
      comparison_operator       = "GREATER_THAN"
      threshold                 = notification.value
      threshold_type            = "PERCENTAGE"
      notification_type         = "ACTUAL"
      subscriber_sns_topic_arns = [aws_sns_topic.this.arn]
    }
  }

  dynamic "notification" {
    for_each = var.forecast_threshold_percent == null ? [] : [var.forecast_threshold_percent]

    content {
      comparison_operator       = "GREATER_THAN"
      threshold                 = notification.value
      threshold_type            = "PERCENTAGE"
      notification_type         = "FORECASTED"
      subscriber_sns_topic_arns = [aws_sns_topic.this.arn]
    }
  }

  depends_on = [aws_sns_topic_policy.this]
}

resource "aws_ce_anomaly_monitor" "this" {
  count = var.enable_anomaly_detection ? 1 : 0

  name              = "${var.name}-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
  tags              = var.tags
}

resource "aws_ce_anomaly_subscription" "this" {
  count = var.enable_anomaly_detection ? 1 : 0

  name             = "${var.name}-anomaly-subscription"
  frequency        = "IMMEDIATE"
  monitor_arn_list = [aws_ce_anomaly_monitor.this[0].arn]
  tags             = var.tags

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.this.arn
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.anomaly_threshold_usd)]
    }
  }

  depends_on = [aws_sns_topic_policy.this]
}
