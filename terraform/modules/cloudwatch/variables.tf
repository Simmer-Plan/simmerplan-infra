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

variable "sns_topic_name" {
  description = "Name of the SNS alert topic"
  type        = string
}

variable "alarm_email" {
  description = "Email address subscribed to alerts. Null skips the subscription (it requires manual confirmation)."
  type        = string
  default     = null
}

variable "lambda_function_name" {
  description = "Lambda function to alarm on"
  type        = string
}

variable "api_name" {
  description = "API name used in alarm naming"
  type        = string
}

variable "api_id" {
  description = "API Gateway (HTTP API) ID to alarm on"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table to alarm on"
  type        = string
}
