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

# Management account — AWS Organizations structure and GitHub Actions OIDC provider.
# The OIDC provider must exist before any CI/CD workflow can authenticate to AWS.

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

module "organizations" {
  source = "../../modules/organizations"

  sandbox_account_email = var.sandbox_account_email
  prod_account_email    = var.prod_account_email
}

module "oidc" {
  source = "../../modules/oidc"

  github_org  = var.github_org
  github_repo = var.github_repo
  environment = "management"
}

# Cross-account providers using OrganizationAccountAccessRole, which AWS automatically
# creates in every member account. Used only to bootstrap TerraformDeployRole.
provider "aws" {
  alias   = "sandbox"
  region  = var.aws_region
  profile = var.aws_profile
  assume_role {
    role_arn = "arn:aws:iam::${var.sandbox_account_id}:role/OrganizationAccountAccessRole"
  }
}

provider "aws" {
  alias   = "prod"
  region  = var.aws_region
  profile = var.aws_profile
  assume_role {
    role_arn = "arn:aws:iam::${var.prod_account_id}:role/OrganizationAccountAccessRole"
  }
}

# TerraformDeployRole in sandbox — assumed by management account credentials for local deployments
resource "aws_iam_role" "terraform_deploy_sandbox" {
  provider = aws.sandbox
  name     = "TerraformDeployRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.account_id}:root" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name      = "TerraformDeployRole"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "terraform_deploy_sandbox_admin" {
  provider   = aws.sandbox
  role       = aws_iam_role.terraform_deploy_sandbox.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# TerraformDeployRole in prod — assumed by management account credentials for local deployments
resource "aws_iam_role" "terraform_deploy_prod" {
  provider = aws.prod
  name     = "TerraformDeployRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${var.account_id}:root" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name      = "TerraformDeployRole"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "terraform_deploy_prod_admin" {
  provider   = aws.prod
  role       = aws_iam_role.terraform_deploy_prod.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
