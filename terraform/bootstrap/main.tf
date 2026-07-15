# Copyright 2026 Dave LeBlanc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Bootstrap — creates the S3 bucket for Terraform remote state.
# Run once manually against each sub-account before any other Terraform workspace init.
# Locking uses S3 native lock files (use_lockfile = true); no DynamoDB table required.

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

variable "aws_region" {
  description = "AWS region for state backend resources"
  type        = string
  default     = "ca-central-1"
}

locals {
  state_bucket_name = "simmerplan-terraform-state-${data.aws_caller_identity.current.account_id}"

  tags = {
    Project   = "simmerplan"
    ManagedBy = "terraform"
    Owner     = "dave-leblanc"
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = local.state_bucket_name
  tags   = local.tags
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

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket                  = aws_s3_bucket.terraform_state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "state_bucket_name" {
  description = "S3 bucket for Terraform state — pass as -backend-config=\"bucket=<value>\""
  value       = aws_s3_bucket.terraform_state.id
}

output "aws_region" {
  description = "AWS region — pass as -backend-config=\"region=<value>\""
  value       = var.aws_region
}
