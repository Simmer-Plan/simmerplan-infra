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

# AWS Organizations — organization structure, OUs, and member accounts.
# If accounts already exist in the organisation, import them before running apply:
#   terraform import module.organizations.aws_organizations_account.sandbox <account-id>
#   terraform import module.organizations.aws_organizations_account.prod    <account-id>

resource "aws_organizations_organization" "this" {
  feature_set = "ALL"

  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
  ]

  aws_service_access_principals = [
    "account.amazonaws.com",
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "sso.amazonaws.com",
  ]
}

resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "sandbox"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_organizational_unit" "prod" {
  name      = "prod"
  parent_id = aws_organizations_organization.this.roots[0].id
}

resource "aws_organizations_account" "sandbox" {
  name      = "simmerplan-sandbox"
  email     = var.sandbox_account_email
  parent_id = aws_organizations_organizational_unit.sandbox.id

  lifecycle {
    # Email can't be changed after account creation without AWS support
    ignore_changes = [email]
  }
}

resource "aws_organizations_account" "prod" {
  name      = "simmerplan-prod"
  email     = var.prod_account_email
  parent_id = aws_organizations_organizational_unit.prod.id

  lifecycle {
    ignore_changes = [email]
  }
}
