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

variable "pool_name" {
  description = "Name of the Cognito user pool"
  type        = string
}

variable "custom_auth_triggers" {
  description = "CUSTOM_AUTH trigger lambdas for Google-federated sign-in (SIM-37). Null skips trigger wiring."
  type = object({
    define_arn           = string
    define_function_name = string
    create_arn           = string
    create_function_name = string
    verify_arn           = string
    verify_function_name = string
  })
  default = null
}
