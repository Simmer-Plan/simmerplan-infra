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

output "api_endpoint" {
  description = "HTTP API endpoint"
  value       = module.api_gateway.api_endpoint
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain"
  value       = module.cloudfront.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (for cache invalidation)"
  value       = module.cloudfront.distribution_id
}

output "static_bucket" {
  description = "Static assets bucket"
  value       = module.s3_static.bucket_id
}

output "dynamodb_table_name" {
  description = "Application table name"
  value       = module.dynamodb.table_name
}

output "cognito_user_pool_id" {
  description = "Cognito user pool ID"
  value       = module.cognito.user_pool_id
}

output "cognito_client_id" {
  description = "Cognito app client ID"
  value       = module.cognito.client_id
}

output "route53_zone_id" {
  description = "Hosted zone ID for the apex domain"
  value       = module.route53.zone_id
}

output "route53_name_servers" {
  description = "Set these at the domain registrar to activate simmerplan.com"
  value       = module.route53.name_servers
}

output "events_bus_name" {
  description = "EventBridge bus name"
  value       = module.eventbridge.bus_name
}

output "alerts_topic_arn" {
  description = "SNS alerts topic ARN"
  value       = module.cloudwatch.alerts_topic_arn
}
