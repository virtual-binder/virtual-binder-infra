resource "aws_sns_topic" "operations" {
  name = "virtual-binder-operations"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.operations.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "virtual-binder-api-5xx"
  alarm_description   = "Errores 5xx de la API en App Runner"
  namespace           = "AWS/AppRunner"
  metric_name         = "5xxStatusResponses"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.operations.arn]

  dimensions = {
    ServiceName = aws_apprunner_service.api.service_name
    ServiceID   = aws_apprunner_service.api.service_id
  }
}

resource "aws_budgets_budget" "monthly" {
  name         = "virtual-binder-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_amount_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  dynamic "notification" {
    for_each = [25, 50, 75, 90]
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.alert_email]
    }
  }
}
