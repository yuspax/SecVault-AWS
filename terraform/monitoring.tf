resource "aws_cloudwatch_log_group" "waf" {
  name              = "aws-waf-logs-juice-shop"
  retention_in_days = 7
}

# AWS creates the CloudWatch Logs delivery policy when logging is enabled.
# The Terraform caller needs the permissions listed in README.md.
resource "aws_wafv2_web_acl_logging_configuration" "main" {
  resource_arn            = aws_wafv2_web_acl.main.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf.arn]

  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ALL"

      condition {
        action_condition {
          action = "BLOCK"
        }
      }
    }
  }

  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  alarm_name          = "juice-shop-waf-blocked-requests"
  alarm_description   = "More than 10 WAF-blocked requests in one minute. Lab alarm: no SNS notifications configured."
  namespace           = "AWS/WAFV2"
  metric_name         = "BlockedRequests"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  dimensions = {
    WebACL = aws_wafv2_web_acl.main.visibility_config[0].metric_name
    Rule   = "ALL"
    Region = "eu-central-1"
  }
}
