# AWS Infrastructure with Terraform

This repository contains Terraform configurations for setting up a AWS infrastructure with EC2 instances, VPC networking, and Systems Manager integration.

## Components Created

1. **S3 Backend**
   - S3 bucket for Terraform state
   - DynamoDB table for state locking
   - Versioning and encryption enabled

2. **Networking**
   - VPC with custom CIDR (10.0.0.0/16)
   - Public subnet in eu-central-1a
   - Internet Gateway
   - Route tables and associations
   - VPC Endpoints for SSM connectivity:
     - SSM endpoint
     - SSM messages endpoint
     - EC2 messages endpoint
     - S3 gateway endpoint

3. **Compute**
   - 3x EC2 instances (c7a.medium)
   - Ubuntu 20.04 LTS AMI
   - Auto-generated SSH key pair
   - SSM Agent installed and configured

4. **Security**
   - Security groups for SSH and SSM access
   - IAM roles and instance profiles for SSM
   - Network ACLs and routing rules

## Prerequisites

- AWS CLI installed and configured
- Terraform v1.0.0 or later
- AWS account with appropriate permissions

## File Structure

```
.
├── backend.tf        # S3 backend configuration
├── main.tf          # Main infrastructure configuration
├── terraform.tfvars # Variable values (not in git)
└── README.md
```

## Usage

1. **Initialize Backend Infrastructure**
```bash
# In the directory with backend.tf
terraform init
terraform apply
```

2. **Deploy Main Infrastructure**
```bash
# In the directory with main.tf
terraform init
terraform apply
```

3. **Accessing Instances**

Via SSM:
```bash
# Using AWS CLI
aws ssm start-session --target i-1234567890abcdef0

# Or use AWS Console:
# Navigate to Systems Manager → Session Manager → Start Session
```

Via SSH (backup method):
```bash
# Save the private key
terraform output -raw private_key > terraform-key-pair.pem
chmod 400 terraform-key-pair.pem

# Connect
ssh -i terraform-key-pair.pem ubuntu@<instance-public-ip>
```

## Default Tags

All resources are tagged with:
```
Name        = "ec2-testing"
region      = "eu"
solution    = "1nce-connect"
environment = "dev"
component   = "kubemajik"
owner       = "andrejs.kuidins"
```
