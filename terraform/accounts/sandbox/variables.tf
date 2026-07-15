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
  description = "AWS region for sandbox resources"
  type        = string
  default     = "ca-central-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "sandbox"
}

variable "aws_profile" {
  description = "Named AWS profile for local runs. Leave unset in CI, where GitHub Actions authenticates via OIDC. The profile must be readable by the Terraform AWS provider — see CLAUDE.md."
  type        = string
  default     = null
}

variable "account_id" {
  description = "AWS account ID for the sandbox account"
  type        = string
}
