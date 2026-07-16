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

variable "function_name" {
  description = "Name of the Lambda function"
  type        = string
}

variable "handler" {
  description = "Lambda handler (file.method)"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime"
  type        = string
  default     = "nodejs22.x"
}

variable "environment_variables" {
  description = "Environment variables for the Lambda function"
  type        = map(string)
  default     = {}
}

variable "timeout" {
  description = "Function timeout in seconds"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Memory allocated to the function in MB"
  type        = number
  default     = 256
}

variable "attach_policy" {
  description = "Attach the inline policy from attach_policy_json (static flag — the JSON itself may be unknown at plan time)"
  type        = bool
  default     = false
}

variable "attach_policy_json" {
  description = "IAM policy JSON attached inline to the execution role (e.g. DynamoDB access). Required when attach_policy is true."
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "CloudWatch log retention for the function log group"
  type        = number
  default     = 30
}
