# backend.tf
provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      Name        = "ec2-testing"
      region      = "eu"
      solution    = "1nce-connect"
      environment = "dev"
      component   = "kubemajik"
      owner       = "andrejs.kuidins"
    }
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "ec2-testing-state-bucket-for-kube-project"
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Optional: DynamoDB table for state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "s3_bucket_name" {
  value = aws_s3_bucket.terraform_state.id
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}
