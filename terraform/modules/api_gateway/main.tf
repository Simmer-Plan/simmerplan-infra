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

# API Gateway module — HTTP API (v2) with Lambda proxy integrations and an
# optional Lambda authorizer (SIM-37). Routes are supplied as a map of route
# keys to { invoke_arn, authorized }; authorized routes require the authorizer.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_apigatewayv2_api" "this" {
  name          = var.api_name
  protocol_type = "HTTP"
}

#tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "access" {
  name              = "/aws/apigateway/${var.api_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.stage_name
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.access.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      httpMethod     = "$context.httpMethod"
      path           = "$context.path"
      status         = "$context.status"
      responseLength = "$context.responseLength"
      integrationErr = "$context.integrationErrorMessage"
    })
  }

  default_route_settings {
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
  }
}

# Payload 2.0 with simple responses disabled: the authorizer receives routeArn
# and returns a full IAM policy with context — matching auth-authorizer.ts in
# simmerplan-app (SIM-29).
resource "aws_apigatewayv2_authorizer" "lambda" {
  count = var.authorizer == null ? 0 : 1

  api_id                            = aws_apigatewayv2_api.this.id
  name                              = "${var.api_name}-authorizer"
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = var.authorizer.invoke_arn
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = false
  identity_sources                  = ["$request.header.Authorization"]
  authorizer_result_ttl_in_seconds  = 300
}

resource "aws_lambda_permission" "authorizer" {
  count = var.authorizer == null ? 0 : 1

  statement_id  = "AllowAPIGatewayAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = var.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/authorizers/${aws_apigatewayv2_authorizer.lambda[0].id}"
}

resource "aws_apigatewayv2_integration" "lambda" {
  for_each = var.routes

  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = each.value.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "this" {
  for_each = var.routes

  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.lambda[each.key].id}"

  authorization_type = each.value.authorized ? "CUSTOM" : "NONE"
  authorizer_id      = each.value.authorized ? aws_apigatewayv2_authorizer.lambda[0].id : null

  lifecycle {
    precondition {
      condition     = !each.value.authorized || var.authorizer != null
      error_message = "Route ${each.key} is authorized but no authorizer was supplied."
    }
  }
}

resource "aws_lambda_permission" "apigw" {
  for_each = var.routes

  statement_id  = "AllowAPIGateway${replace(each.key, "/[^0-9A-Za-z]/", "")}"
  action        = "lambda:InvokeFunction"
  function_name = regex("function:([^/]+)/invocations", each.value.invoke_arn)[0]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}
