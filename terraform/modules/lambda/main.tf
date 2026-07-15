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

# Lambda module — function, execution role, and log group. The function is
# created with an embedded stub package; real code is deployed by Ansible
# (deploy_lambda.yml), so Terraform ignores code changes after creation.

terraform {
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

# Stub package so the function exists before the first Ansible deploy. It
# answers every request with 200/ok, which the health check playbook relies
# on for first-boot validation.
data "archive_file" "stub" {
  type        = "zip"
  output_path = "${path.module}/build/${var.function_name}-stub.zip"

  source {
    filename = "index.mjs"
    content  = <<-EOT
      export const handler = async () => ({
        statusCode: 200,
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ status: "ok", deployed: "stub" }),
      });
    EOT
  }
}

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy" "extra" {
  # Gated on a static flag: the JSON often references ARNs unknown at plan
  # time, which count cannot depend on.
  count  = var.attach_policy ? 1 : 0
  name   = "${var.function_name}-policy"
  role   = aws_iam_role.this.id
  policy = var.attach_policy_json
}

# Log group is created explicitly so retention is controlled and the group is
# destroyed with the stack. CloudWatch log groups use AWS-managed encryption.
#tfsec:ignore:aws-cloudwatch-log-group-customer-key
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  role          = aws_iam_role.this.arn
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size

  filename         = data.archive_file.stub.output_path
  source_code_hash = data.archive_file.stub.output_base64sha256

  tracing_config {
    mode = "Active"
  }

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [1] : []
    content {
      variables = var.environment_variables
    }
  }

  depends_on = [aws_cloudwatch_log_group.this]

  # Ansible owns code deploys after creation; without this, every plan after a
  # deploy would try to roll the function back to the stub package.
  lifecycle {
    ignore_changes = [filename, source_code_hash]
  }
}
