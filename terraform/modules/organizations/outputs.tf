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

output "organization_id" {
  description = "ID of the AWS Organization"
  value       = aws_organizations_organization.this.id
}

output "sandbox_account_id" {
  description = "AWS account ID for the sandbox member account"
  value       = aws_organizations_account.sandbox.id
}

output "prod_account_id" {
  description = "AWS account ID for the prod member account"
  value       = aws_organizations_account.prod.id
}

output "sandbox_ou_id" {
  description = "ID of the sandbox organisational unit"
  value       = aws_organizations_organizational_unit.sandbox.id
}

output "prod_ou_id" {
  description = "ID of the prod organisational unit"
  value       = aws_organizations_organizational_unit.prod.id
}
