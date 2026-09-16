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
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "invoke" {
  # Direct foundation-model invocation. Not region-pinned: a cross-region
  # inference profile fans out to the same model in other regions, and the
  # caller needs invoke rights on each of those foundation-model ARNs.
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = [
      for prefix in var.allowed_model_prefixes :
      "arn:aws:bedrock:*::foundation-model/${prefix}*"
    ]
  }

  # Current Claude models are invoked through an inference profile rather than a
  # bare model id, which requires invoke rights on the profile ARN as well.
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    #tfsec:ignore:aws-iam-no-policy-wildcards
    resources = [
      "arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:inference-profile/*",
      "arn:aws:bedrock:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:application-inference-profile/*",
    ]
  }
}

resource "aws_iam_policy" "invoke" {
  name   = var.policy_name
  policy = data.aws_iam_policy_document.invoke.json
}
