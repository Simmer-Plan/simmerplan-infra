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

  # INVITE records carry TTL = expiry + 7 days for auto-cleanup (SIM-6/SIM-37).
  ttl_attribute = "TTL"
}

module "secrets" {
  source = "../../modules/secrets"

  # Path-style names are the contract with simmerplan-app (its lib/secrets.ts
  # resolves simmerplan/<env>/<name>). Values are set out of band post-apply
  # via rotate_secrets.yml — never through Terraform state.
  secrets = {
    "simmerplan/${var.environment}/invite-signing-key"         = "HS256 key for household invite JWTs (SIM-29)"
    "simmerplan/${var.environment}/google-oauth-client-id"     = "Google OAuth web client ID for Cognito federation (SIM-29)"
    "simmerplan/${var.environment}/google-oauth-client-secret" = "Google OAuth web client secret (SIM-29)"
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

# ── Auth stack (SIM-37, consumed by simmerplan-app SIM-29) ────────────────────

locals {
  auth_secret_arns = values(module.secrets.secret_arns)
  cognito_env = {
    ENVIRONMENT          = var.environment
    COGNITO_USER_POOL_ID = module.cognito.user_pool_id
    COGNITO_CLIENT_ID    = module.cognito.client_id
  }
}

data "aws_iam_policy_document" "secrets_read" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = local.auth_secret_arns
  }
}

data "aws_iam_policy_document" "auth_lambda" {
  source_policy_documents = [data.aws_iam_policy_document.secrets_read.json]

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query",
      "dynamodb:BatchGetItem",
    ]
    resources = [module.dynamodb.table_arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:AdminGetUser",
      "cognito-idp:AdminCreateUser",
      "cognito-idp:AdminSetUserPassword",
      "cognito-idp:AdminUpdateUserAttributes",
    ]
    resources = [module.cognito.user_pool_arn]
  }
}

# Validates Google idTokens during the CUSTOM_AUTH exchange.
data "aws_iam_policy_document" "verify_trigger" {
  source_policy_documents = [data.aws_iam_policy_document.secrets_read.json]
}

module "lambda_authorizer" {
  source = "../../modules/lambda"

  function_name = "simmerplan-authorizer-${var.environment}"
  handler       = "auth-authorizer.handler"

  # JWKS verification only — no AWS API access required.
  environment_variables = local.cognito_env
  log_retention_days    = 90
}

module "lambda_auth" {
  source = "../../modules/lambda"

  function_name = "simmerplan-auth-${var.environment}"
  handler       = "auth-handler.handler"

  environment_variables = merge(local.cognito_env, {
    DYNAMODB_TABLE = module.dynamodb.table_name
  })

  attach_policy      = true
  attach_policy_json = data.aws_iam_policy_document.auth_lambda.json
  log_retention_days = 90
}

module "lambda_household" {
  source = "../../modules/lambda"

  function_name = "simmerplan-household-${var.environment}"
  handler       = "household-handler.handler"

  environment_variables = merge(local.cognito_env, {
    DYNAMODB_TABLE = module.dynamodb.table_name
  })

  attach_policy      = true
  attach_policy_json = data.aws_iam_policy_document.auth_lambda.json
  log_retention_days = 90
}

module "lambda_cognito_define" {
  source = "../../modules/lambda"

  function_name      = "simmerplan-cognito-define-${var.environment}"
  handler            = "cognito-define-auth-challenge.handler"
  log_retention_days = 90
}

module "lambda_cognito_create" {
  source = "../../modules/lambda"

  function_name      = "simmerplan-cognito-create-${var.environment}"
  handler            = "cognito-create-auth-challenge.handler"
  log_retention_days = 90
}

module "lambda_cognito_verify" {
  source = "../../modules/lambda"

  function_name = "simmerplan-cognito-verify-${var.environment}"
  handler       = "cognito-verify-auth-challenge.handler"

  environment_variables = {
    ENVIRONMENT = var.environment
  }

  attach_policy      = true
  attach_policy_json = data.aws_iam_policy_document.verify_trigger.json
  log_retention_days = 90
}

module "api_gateway" {
  source = "../../modules/api_gateway"

  api_name   = "simmerplan-api-${var.environment}"
  stage_name = "$default"

  # /auth is where tokens come from — everything else requires one.
  # /health is public so the post-deploy health check can reach the api
  # lambda without a token (stub returns 200/ok; the app serves it post-deploy).
  routes = {
    "GET /health" = {
      invoke_arn = module.lambda_api.invoke_arn
    }
    "ANY /auth/{proxy+}" = {
      invoke_arn = module.lambda_auth.invoke_arn
    }
    "ANY /household/{proxy+}" = {
      invoke_arn = module.lambda_household.invoke_arn
      authorized = true
    }
    "GET /household" = {
      invoke_arn = module.lambda_household.invoke_arn
      authorized = true
    }
    "ANY /{proxy+}" = {
      invoke_arn = module.lambda_api.invoke_arn
      authorized = true
    }
  }

  authorizer = {
    invoke_arn    = module.lambda_authorizer.invoke_arn
    function_name = module.lambda_authorizer.function_name
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

  custom_auth_triggers = {
    define_arn           = module.lambda_cognito_define.function_arn
    define_function_name = module.lambda_cognito_define.function_name
    create_arn           = module.lambda_cognito_create.function_arn
    create_function_name = module.lambda_cognito_create.function_name
    verify_arn           = module.lambda_cognito_verify.function_arn
    verify_function_name = module.lambda_cognito_verify.function_name
  }
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
