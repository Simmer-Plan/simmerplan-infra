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

variable "api_name" {
  description = "Name of the API Gateway"
  type        = string
}

variable "stage_name" {
  description = "Deployment stage name"
  type        = string
}

variable "routes" {
  description = "Map of route keys to { invoke_arn, authorized }. Authorized routes go behind the Lambda authorizer."
  type = map(object({
    invoke_arn = string
    authorized = optional(bool, false)
  }))
  default = {}
}

variable "authorizer" {
  description = "Lambda authorizer for authorized routes. Null when every route is public."
  type = object({
    invoke_arn    = string
    function_name = string
  })
  default = null
}

variable "log_retention_days" {
  description = "CloudWatch retention for the access log group"
  type        = number
  default     = 30
}

variable "throttling_burst_limit" {
  description = "Default route throttling burst limit"
  type        = number
  default     = 100
}

variable "throttling_rate_limit" {
  description = "Default route steady-state requests per second"
  type        = number
  default     = 50
}
