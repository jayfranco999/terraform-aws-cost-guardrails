variable "name" {
  description = "Short name used to prefix every resource this module creates."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{3,32}$", var.name))
    error_message = "name must be 3 to 32 characters of lowercase letters, digits or hyphens."
  }
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget in USD. Alerts fire against this figure."
  type        = number

  validation {
    condition     = var.monthly_budget_usd > 0
    error_message = "monthly_budget_usd must be greater than zero."
  }
}

variable "alert_emails" {
  description = "Email addresses that receive budget and anomaly alerts. Each is subscribed to the SNS topic."
  type        = list(string)

  validation {
    condition     = length(var.alert_emails) > 0
    error_message = "Provide at least one address in alert_emails, otherwise the alarms are silent."
  }

  validation {
    condition     = alltrue([for e in var.alert_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "Every entry in alert_emails must look like an email address."
  }
}

variable "actual_thresholds_percent" {
  description = "Percentages of the budget at which to alert on ACTUAL spend already incurred."
  type        = list(number)
  default     = [50, 80, 100]

  validation {
    condition     = alltrue([for t in var.actual_thresholds_percent : t > 0 && t <= 200])
    error_message = "Each actual threshold must be between 1 and 200 percent."
  }
}

variable "forecast_threshold_percent" {
  description = "Percentage of the budget at which to alert on FORECAST spend. This is the alert that gives you time to react. Set to null to disable."
  type        = number
  default     = 100

  validation {
    condition     = var.forecast_threshold_percent == null || (var.forecast_threshold_percent > 0 && var.forecast_threshold_percent <= 200)
    error_message = "forecast_threshold_percent must be between 1 and 200, or null to disable."
  }
}

variable "anomaly_threshold_usd" {
  description = "Minimum USD impact before a cost anomaly raises an alert. Too low and the alerts become noise you learn to ignore."
  type        = number
  default     = 50

  validation {
    condition     = var.anomaly_threshold_usd >= 0
    error_message = "anomaly_threshold_usd cannot be negative."
  }
}

variable "enable_anomaly_detection" {
  description = "Create AWS Cost Anomaly Detection alongside the budget. Catches a spike that a monthly budget would not notice until late in the month."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every taggable resource."
  type        = map(string)
  default     = {}
}
