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

# Cognito module — user pool and SPA app client. Sign-in is Google-federated
# through the CUSTOM_AUTH flow (SIM-37): the trigger lambdas validate the
# Google idToken, and custom:householdId carries household membership in every
# ID token so the API authorizer never needs a database lookup (SIM-8).

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_cognito_user_pool" "this" {
  name = var.pool_name

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length    = 12
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # Household membership claim — extracted from verified ID tokens by the
  # Lambda authorizer (SIM-8 approved decision).
  schema {
    name                = "householdId"
    attribute_data_type = "String"
    mutable             = true
    required            = false

    string_attribute_constraints {
      min_length = 0
      max_length = 36
    }
  }

  dynamic "lambda_config" {
    for_each = var.custom_auth_triggers == null ? [] : [var.custom_auth_triggers]
    content {
      define_auth_challenge          = lambda_config.value.define_arn
      create_auth_challenge          = lambda_config.value.create_arn
      verify_auth_challenge_response = lambda_config.value.verify_arn
    }
  }
}

# Cognito must be allowed to invoke each trigger.
resource "aws_lambda_permission" "triggers" {
  for_each = var.custom_auth_triggers == null ? {} : {
    define = var.custom_auth_triggers.define_function_name
    create = var.custom_auth_triggers.create_function_name
    verify = var.custom_auth_triggers.verify_function_name
  }

  statement_id  = "AllowCognitoInvoke"
  action        = "lambda:InvokeFunction"
  function_name = each.value
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.this.arn
}

resource "aws_cognito_user_pool_client" "this" {
  name         = "${var.pool_name}-client"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret               = false
  prevent_user_existence_errors = "ENABLED"

  explicit_auth_flows = [
    "ALLOW_CUSTOM_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  # Auth Planning doc (SIM-8): access/ID 1 hour, refresh 30 days.
  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}
