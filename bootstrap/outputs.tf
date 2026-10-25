output "state_bucket_name" {
  description = "S3 bucket used by the application Terraform backend"
  value       = aws_s3_bucket.state.id
}
