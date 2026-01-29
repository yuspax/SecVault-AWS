# SecVault-AWS

A secure cloud infrastructure project demonstrating "Defense in Depth" principles. It deploys an intentionally vulnerable web application (**OWASP Juice Shop**) using Terraform and protects it with an enterprise-grade security layer (AWS WAF & ALB).

## Quick Start

**Prerequisites:**
- Terraform installed (v1.0+)
- AWS CLI configured with credentials

**Deploy Infrastructure:**

```bash
git clone https://github.com/yuspax/SecVault-AWS.git

# Initialize Terraform (download providers)
terraform init

# Build infrastructure
terraform apply --auto-approve
```
Note: Provisioning the Application Load Balancer and WAF may take 3-5 minutes.


## What It Does 
This project automatically builds a secure AWS environment: 

- VPC & Network: Creates a custom Virtual Private Cloud with public subnets.

- Compute: Deploys a Dockerized instance of OWASP Juice Shop on EC2.

Security Layer:

- ALB: Routes traffic and handles SSL/Termination.

- AWS WAF: Inspects incoming traffic and blocks malicious requests (SQL Injection, XSS).

- Architecture Flow: User -> AWS WAF (Filters Attacks) -> Load Balancer -> EC2 Instance -> Juice Shop App

## Demonstration
After deployment, Terraform outputs a secure WAF link.

1. Copy the link and insert it into the chaos_test.sh script.

2. Run the script to simulate an attack.

Result: 🛡️ 403 Forbidden (Blocked by AWS WAF).

## Configuration
Infrastructure settings are defined in main.tf and provider.tf.

Key Variables:

Region: eu-central-1 (Frankfurt)

Instance Type: t3.micro

Backend: State is stored in S3 with DynamoDB locking.


