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

# Prod account — same module set as sandbox (SIM-33) with prod-specific
# configuration (SIM-35): DynamoDB deletion protection + PITR, the
# simmerplan.com apex domain, secret recovery windows, and no force-destroy
# anywhere. Applies go through CI/CD with the manual approval gate on the
# prod GitHub environment — do not apply this workspace directly.
#
# Custom-domain resources are gated behind enable_custom_domain: the apex
# zone's name servers must be set at the domain registrar before ACM
# validation can complete. First apply with the flag off, update the
# registrar with the route53_name_servers output, then flip and re-apply.

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

# Credentials come from the management account, which then assumes TerraformDeployRole
# in this account. Locally that is var.aws_profile; in CI it is the GitHub Actions role.
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/TerraformDeployRole"
  }

  default_tags {
    tags = {
      Project     = "simmerplan"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# CloudFront only accepts ACM certificates issued in us-east-1.
provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"
  profile = var.aws_profile
  assume_role {
    role_arn = "arn:aws:iam::${var.account_id}:role/TerraformDeployRole"
  }

  default_tags {
    tags = {
      Project     = "simmerplan"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ── Data layer ────────────────────────────────────────────────────────────────

module "dynamodb" {
  source = "../../modules/dynamodb"

  table_name = "simmerplan-${var.environment}"
  hash_key   = "PK"
  range_key  = "SK"

  global_secondary_indexes = [
    {
      name      = "GSI1"
      hash_key  = "GSI1PK"
      range_key = "GSI1SK"
    },
    {
      name      = "GSI2"
      hash_key  = "GSI2PK"
      range_key = "GSI2SK"
    },
  ]

  # Prod: protected data (SIM-35 acceptance criteria).
  point_in_time_recovery = true
  deletion_protection    = true
}

module "secrets" {
  source = "../../modules/secrets"

  secrets = {
    "simmerplan-google-oauth-${var.environment}" = "Google OAuth client credentials for Cognito federation (SIM-29)"
  }

  # Prod: keep the full recovery window for deleted secrets.
  recovery_window_in_days = 30
}

# ── Compute and API ───────────────────────────────────────────────────────────

module "bedrock" {
  source = "../../modules/bedrock"

  policy_name = "simmerplan-bedrock-invoke-${var.environment}"
}

data "aws_iam_policy_document" "api_lambda" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
    ]
    # The /index/* wildcard is scoped to this one table — it is the only way
    # to grant query access to its GSIs.
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = [
      module.dynamodb.table_arn,
      "${module.dynamodb.table_arn}/index/*",
    ]
  }
}

module "lambda_api" {
  source = "../../modules/lambda"

  function_name = "simmerplan-api-${var.environment}"
  handler       = "index.handler"

  environment_variables = {
    DYNAMODB_TABLE = module.dynamodb.table_name
    ENVIRONMENT    = var.environment
  }

  attach_policy      = true
  attach_policy_json = data.aws_iam_policy_document.api_lambda.json

  # Prod: keep logs longer than the 30-day module default.
  log_retention_days = 90
}

resource "aws_iam_role_policy_attachment" "api_bedrock" {
  role       = module.lambda_api.role_name
  policy_arn = module.bedrock.policy_arn
}

module "api_gateway" {
  source = "../../modules/api_gateway"

  api_name   = "simmerplan-api-${var.environment}"
  stage_name = "$default"

  lambda_integrations = {
    "ANY /{proxy+}" = module.lambda_api.invoke_arn
  }

  log_retention_days = 90
}

# ── Static delivery ───────────────────────────────────────────────────────────

module "s3_static" {
  source = "../../modules/s3"

  bucket_name = "simmerplan-static-${var.environment}"
  # Prod: never allow teardown with objects present.
  force_destroy = false
}

module "route53" {
  source = "../../modules/route53"

  domain_name              = var.domain_name
  create_alias_records     = true
  alias_target_domain_name = module.cloudfront.domain_name
  alias_target_zone_id     = module.cloudfront.hosted_zone_id
}

module "acm" {
  source = "../../modules/acm"
  count  = var.enable_custom_domain ? 1 : 0

  providers = { aws = aws.us_east_1 }

  domain_name = var.domain_name
  # Cover www alongside the apex.
  subject_alternative_names = ["www.${var.domain_name}"]
  zone_id                   = module.route53.zone_id
}

module "cloudfront" {
  source = "../../modules/cloudfront"

  bucket_id                   = module.s3_static.bucket_id
  bucket_arn                  = module.s3_static.bucket_arn
  bucket_regional_domain_name = module.s3_static.bucket_regional_domain_name

  aliases             = var.enable_custom_domain ? [var.domain_name, "www.${var.domain_name}"] : []
  acm_certificate_arn = var.enable_custom_domain ? module.acm[0].certificate_arn : null
}

# ── Eventing and observability ────────────────────────────────────────────────

module "eventbridge" {
  source = "../../modules/eventbridge"

  bus_name = "simmerplan-events-${var.environment}"
}

module "cognito" {
  source = "../../modules/cognito"

  pool_name = "simmerplan-users-${var.environment}"
}

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  sns_topic_name       = "simmerplan-alerts-${var.environment}"
  alarm_email          = var.alarm_email
  lambda_function_name = module.lambda_api.function_name
  api_name             = "simmerplan-api-${var.environment}"
  api_id               = module.api_gateway.api_id
  dynamodb_table_name  = module.dynamodb.table_name
}
