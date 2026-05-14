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

variable "aws_region" {
  description = "AWS region for management account resources"
  type        = string
  default     = "ca-central-1"
}

variable "account_id" {
  description = "AWS account ID for the management account"
  type        = string
}

variable "github_org" {
  description = "GitHub organisation name (owner of the repository)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix)"
  type        = string
}

variable "sandbox_account_id" {
  description = "AWS account ID for the sandbox member account (used to bootstrap TerraformDeployRole)"
  type        = string
}

variable "prod_account_id" {
  description = "AWS account ID for the prod member account (used to bootstrap TerraformDeployRole)"
  type        = string
}

variable "sandbox_account_email" {
  description = "Root email address for the sandbox AWS member account"
  type        = string
}

variable "prod_account_email" {
  description = "Root email address for the prod AWS member account"
  type        = string
}
