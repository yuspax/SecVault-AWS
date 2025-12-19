resource "aws_wafv2_web_acl" "main" {
  name        = "juice-shop-waf"
  description = "WAF for Juice Shop Project"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "juice-shop-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "Custom-Block-CMD"
    priority = 1
    action {
      block {}
    }
    statement {
      or_statement {
        statement {
          byte_match_statement {
            search_string = "cat /etc/shadow"
            field_to_match {
              body {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
            positional_constraint = "CONTAINS"
          }
        }
        statement {
          byte_match_statement {
            search_string = "; cat"
            field_to_match {
              body {}
            }
            text_transformation {
              priority = 0
              type     = "LOWERCASE"
            }
            positional_constraint = "CONTAINS"
          }
        }
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CustomCmdRule"
      sampled_requests_enabled   = true
    }
  }

  # 1. SQL Injection
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 10
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRule"
      sampled_requests_enabled   = true
    }
  }

  # 2. Linux OS
  rule {
    name     = "AWS-AWSManagedRulesLinuxRuleSet"
    priority = 20
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "LinuxRule"
      sampled_requests_enabled   = true
    }
  }

  # 3. Unix POSIX
  rule {
    name     = "AWS-AWSManagedRulesUnixRuleSet"
    priority = 30
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesUnixRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "UnixRule"
      sampled_requests_enabled   = true
    }
  }

  # 4. Common Rules (XSS)
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 40
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRule"
      sampled_requests_enabled   = true
    }
  }

  # 5. Known Bad Inputs (Log4Shell)
  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 50
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BadInputsRule"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = aws_lb.main.arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}