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

variable "domain_name" {
  description = "Domain name for the hosted zone"
  type        = string
}

variable "create_alias_records" {
  description = "Create A/AAAA alias records (static flag — the target values may be unknown at plan time)"
  type        = bool
  default     = false
}

variable "alias_target_domain_name" {
  description = "DNS name of the alias target (e.g. CloudFront distribution domain). Required when create_alias_records is true."
  type        = string
  default     = null
}

variable "alias_target_zone_id" {
  description = "Hosted zone ID of the alias target (CloudFront is always Z2FDTNDATAQYW2)"
  type        = string
  default     = null
}
