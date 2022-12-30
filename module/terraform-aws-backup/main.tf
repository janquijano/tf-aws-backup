data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id       = data.aws_caller_identity.current.account_id
  plan_enabled     = var.plan_enabled
  iam_role_enabled = var.iam_role_enabled
  iam_role_name    = var.iam_role_name
  iam_role_arn     = join("", var.iam_role_enabled ? aws_iam_role.default.*.arn : data.aws_iam_role.existing.*.arn)
  vault_enabled    = var.vault_enabled
  vault_name       = coalesce(var.vault_name, local.account_id)
  vault_id         = join("", local.vault_enabled ? aws_backup_vault.default.*.id : data.aws_backup_vault.existing.*.id)
  vault_arn        = join("", local.vault_enabled ? aws_backup_vault.default.*.arn : data.aws_backup_vault.existing.*.arn)

  # This is for backwards compatibility
  single_rule = [{
    name                     = local.account_id
    schedule                 = var.schedule
    start_window             = var.start_window
    completion_window        = var.completion_window
    enable_continuous_backup = var.enable_continuous_backup
    lifecycle = {
      cold_storage_after = var.cold_storage_after
      delete_after       = var.delete_after
    }
    copy_action = {
      destination_vault_arn = var.destination_vault_arn
      lifecycle = {
        cold_storage_after = var.copy_action_cold_storage_after
        delete_after       = var.copy_action_delete_after
      }
    }
  }]
  compatible_rules = length(var.rules) == 0 ? local.single_rule : [{ for k, v in local.single_rule[0] : k => v }]
}

data "aws_partition" "current" {}

resource "aws_backup_vault" "default" {
  count       = local.vault_enabled ? 1 : 0
  name        = local.vault_name
  kms_key_arn = var.kms_key_arn
  tags        = var.tags
}

data "aws_backup_vault" "existing" {
  count = var.vault_enabled == false ? 1 : 0
  name  = local.vault_name
}

resource "aws_backup_plan" "default" {
  count = local.plan_enabled ? 1 : 0
  name  = var.plan_name_suffix == null ? local.account_id : format("%s_%s", local.account_id, var.plan_name_suffix)

  dynamic "rule" {
    for_each = length(var.rules) > 0 ? var.rules : local.compatible_rules

    content {
      rule_name                = lookup(rule.value, "name", "${local.account_id}-${rule.key}")
      target_vault_name        = join("", local.vault_enabled ? aws_backup_vault.default.*.name : data.aws_backup_vault.existing.*.name)
      schedule                 = lookup(rule.value, "schedule", null)
      start_window             = lookup(rule.value, "start_window", null)
      completion_window        = lookup(rule.value, "completion_window", null)
      recovery_point_tags      = lookup(rule.value, "recovery_point_tags", null)
      enable_continuous_backup = lookup(rule.value, "enable_continuous_backup", null)

      dynamic "lifecycle" {
        for_each = lookup(rule.value, "lifecycle", null) != null ? [true] : []

        content {
          cold_storage_after = lookup(rule.value.lifecycle, "cold_storage_after", null)
          delete_after       = lookup(rule.value.lifecycle, "delete_after", null)
        }
      }

      dynamic "copy_action" {
        for_each = try(lookup(rule.value.copy_action, "destination_vault_arn", null), null) != null ? [true] : []

        content {
          destination_vault_arn = lookup(rule.value.copy_action, "destination_vault_arn", null)

          dynamic "lifecycle" {
            for_each = lookup(rule.value.copy_action, "lifecycle", null) != null != null ? [true] : []

            content {
              cold_storage_after = lookup(rule.value.copy_action.lifecycle, "cold_storage_after", null)
              delete_after       = lookup(rule.value.copy_action.lifecycle, "delete_after", null)
            }
          }
        }
      }
    }
  }

  dynamic "advanced_backup_setting" {
    for_each = var.advanced_backup_settings
    content {
      backup_options = lookup(advanced_backup_setting.value.backup_options, "backup_options", null)
      resource_type = lookup(advanced_backup_setting.value.resource_type, "resource_type", null)
    }
  }

  tags = var.tags
}

data "aws_iam_policy_document" "assume_role" {
  count = local.iam_role_enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "default" {
  count                = local.iam_role_enabled ? 1 : 0
  name                 = local.iam_role_name
  assume_role_policy   = join("", data.aws_iam_policy_document.assume_role.*.json)
  tags                 = var.tags
  permissions_boundary = var.permissions_boundary
}

data "aws_iam_role" "existing" {
  count = var.iam_role_enabled == false ? 1 : 0
  name  = local.iam_role_name
}

resource "aws_iam_role_policy_attachment" "default" {
  count      = local.iam_role_enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupFullAccess"
  role       = join("", aws_iam_role.default.*.name)
}

resource "aws_iam_role_policy_attachment" "backup" {
  count      = local.iam_role_enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
  role       = join("", aws_iam_role.default.*.name)
}

resource "aws_iam_role_policy_attachment" "s3_backup" {
  count      = local.iam_role_enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup"
  role       = join("", aws_iam_role.default.*.name)
}

resource "aws_iam_role_policy_attachment" "restore" {
  count      = local.iam_role_enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
  role       = join("", aws_iam_role.default.*.name)
}

resource "aws_iam_role_policy_attachment" "s3_restore" {
  count      = local.iam_role_enabled ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Restore"
  role       = join("", aws_iam_role.default.*.name)
}

resource "aws_iam_role_policy_attachment" "iam_pass_role" {
  count      = local.iam_role_enabled ? 1 : 0
  policy_arn = aws_iam_policy.iam_pass_role[0].arn
  role       = join("", aws_iam_role.default.*.name)
}

resource "aws_backup_selection" "default" {
  count         = local.plan_enabled ? 1 : 0
  name          = var.plan_name_suffix == null ? local.account_id : format("%s_%s", local.account_id, var.plan_name_suffix)
  iam_role_arn  = local.iam_role_arn
  plan_id       = join("", aws_backup_plan.default.*.id)
  resources     = var.backup_resources
  not_resources = var.not_resources
  dynamic "condition" {
    for_each = var.condition_tags
    content {
      dynamic "string_equals" {
        for_each = condition.value["type"]
        content {
          key   = condition.value["key"]
          value = condition.value["value"]
        }
      }
    }
  }
}


resource "aws_iam_policy" "iam_pass_role" {
  count      = local.iam_role_enabled ? 1 : 0
  name        = "iam-pass-role-policy"
  path        = "/"
  description = "Give IAM PassRole permission to the AWS Backup role"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "IAMPassRole",
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "*"
        }
    ]
}
EOF
}
