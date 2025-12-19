resource "aws_cloudwatch_log_group" "juice_shop_logs" {
  name              = "/ecs/juice-shop"
  retention_in_days = 7
}

resource "aws_cloudwatch_dashboard" "waf_dashboard" {
  dashboard_name = "JuiceShop-Security-Monitor"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          metrics = [
            [
              "AWS/WAFV2", "BlockedRequests", "WebACL", aws_wafv2_web_acl.main.name, "Region", "eu-central-1",
              { color = "#d62728", label = "Blocked Attacks" }
            ],
            [
              "AWS/WAFV2", "AllowedRequests", "WebACL", aws_wafv2_web_acl.main.name, "Region", "eu-central-1",
              { color = "#2ca02c", label = "Normal Traffic" }
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = "eu-central-1"
          title   = "WAF Traffic Analysis"
          period  = 300
        }
      }
    ]
  })
}