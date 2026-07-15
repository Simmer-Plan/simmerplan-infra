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

# Route 53 module — hosted zone for the environment domain, with optional
# A/AAAA alias records pointing at a CloudFront distribution.
#
# Delegation is out of band: after the zone is created, its name servers must
# be registered at the parent (registrar for the apex; the apex zone for
# environment subdomains). The zone resolves nothing until then.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_route53_zone" "this" {
  name = var.domain_name
}

resource "aws_route53_record" "alias_a" {
  count = var.create_alias_records ? 1 : 0

  zone_id = aws_route53_zone.this.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alias_target_domain_name
    zone_id                = var.alias_target_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "alias_aaaa" {
  count = var.create_alias_records ? 1 : 0

  zone_id = aws_route53_zone.this.zone_id
  name    = var.domain_name
  type    = "AAAA"

  alias {
    name                   = var.alias_target_domain_name
    zone_id                = var.alias_target_zone_id
    evaluate_target_health = false
  }
}
