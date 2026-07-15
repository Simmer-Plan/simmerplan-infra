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

variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "billing_mode" {
  description = "Billing mode (PAY_PER_REQUEST or PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "hash_key" {
  description = "Partition key attribute name"
  type        = string
}

variable "range_key" {
  description = "Sort key attribute name"
  type        = string
  default     = null
}

variable "global_secondary_indexes" {
  description = "List of GSI configurations ({name, hash_key, range_key?, projection_type?}). All key attributes are assumed to be strings."
  type        = any
  default     = []
}

variable "point_in_time_recovery" {
  description = "Enable point-in-time recovery"
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Enable deletion protection (required for prod — SIM-35)"
  type        = bool
  default     = false
}

variable "ttl_attribute" {
  description = "Attribute holding the item expiry as Unix seconds (e.g. TTL on INVITE records). Null disables TTL."
  type        = string
  default     = null
}
