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

# DynamoDB module — single-table design per SIM-6. All key attributes are
# strings; the schema (PK/SK + GSI1/GSI2) is defined by the caller.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  # Every key attribute referenced by the table or a GSI must have a matching
  # attribute definition. All Simmerplan keys are strings (SIM-6).
  attribute_names = distinct([
    for a in concat(
      [var.hash_key, var.range_key],
      flatten([
        for g in var.global_secondary_indexes : [g.hash_key, try(g.range_key, null)]
      ])
    ) : a if a != null
  ])
}

# Encryption uses the AWS-managed DynamoDB key; a customer-managed CMK adds
# cost and rotation overhead without a compliance driver for this app.
#tfsec:ignore:aws-dynamodb-enable-at-rest-encryption tfsec:ignore:aws-dynamodb-table-customer-key
resource "aws_dynamodb_table" "this" {
  name                        = var.table_name
  billing_mode                = var.billing_mode
  hash_key                    = var.hash_key
  range_key                   = var.range_key
  deletion_protection_enabled = var.deletion_protection

  dynamic "attribute" {
    for_each = local.attribute_names
    content {
      name = attribute.value
      type = "S"
    }
  }

  dynamic "global_secondary_index" {
    for_each = var.global_secondary_indexes
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = try(global_secondary_index.value.range_key, null)
      projection_type = try(global_secondary_index.value.projection_type, "ALL")
    }
  }

  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  server_side_encryption {
    enabled = true
  }
}
