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

variable "bucket_id" {
  description = "Name (ID) of the S3 origin bucket"
  type        = string
}

variable "bucket_arn" {
  description = "ARN of the S3 origin bucket (for the OAC bucket policy)"
  type        = string
}

variable "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 origin bucket"
  type        = string
}

variable "aliases" {
  description = "Custom domain aliases. Requires acm_certificate_arn."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN (must be in us-east-1). Null uses the default CloudFront certificate."
  type        = string
  default     = null
}

variable "price_class" {
  description = "CloudFront price class"
  type        = string
  default     = "PriceClass_100"
}
