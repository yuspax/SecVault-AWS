output "alb_dns_name" {
  description = "Public ALB hostname; this lab currently uses HTTP"
  value       = aws_lb.main.dns_name
}

output "application_url" {
  description = "WAF-protected Juice Shop URL"
  value       = "http://${aws_lb.main.dns_name}"
}

output "waf_log_group_name" {
  value = aws_cloudwatch_log_group.waf.name
}

output "waf_alarm_name" {
  value = aws_cloudwatch_metric_alarm.waf_blocked_requests.alarm_name
}
