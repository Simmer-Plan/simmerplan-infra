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

# Bedrock module — IAM policy granting invoke access to foundation models.
# Model access itself is enabled per account out of band (there is no
# Terraform resource for it); see ansible/playbooks/enable_bedrock.yml.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

data "aws_region" "current" {}

data "aws_iam_policy_document" "invoke" {
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = [
      for prefix in var.allowed_model_prefixes :
      "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${prefix}*"
    ]
  }
}

resource "aws_iam_policy" "invoke" {
  name   = var.policy_name
  policy = data.aws_iam_policy_document.invoke.json
}
