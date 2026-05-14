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

output "role_arn" {
  description = "ARN of the GitHub Actions IAM role (use in workflow: role-to-assume)"
  value       = module.oidc.role_arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider"
  value       = module.oidc.oidc_provider_arn
}

output "sandbox_account_id" {
  description = "AWS account ID for the sandbox member account"
  value       = module.organizations.sandbox_account_id
}

output "prod_account_id" {
  description = "AWS account ID for the prod member account"
  value       = module.organizations.prod_account_id
}
