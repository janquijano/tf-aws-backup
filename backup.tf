
module "backup" {
  source  = "./modules/terraform-aws-backup"

  plan_name_suffix = "daily"
  backup_resources = ["*"]
  not_resources    = ["arn:aws:ec2:*:*:volume/*"]
  condition_tags   = [
    {
      type  = ["string_equals"]
      key   = "aws:ResourceTag/backup-schedule"
      value = "daily"
    }
  ]

  rules = [
    {
      name              = "${local.account_id}-daily"
      schedule          = var.schedule
      start_window      = var.start_window
      completion_window = var.completion_window
      lifecycle = {
        #cold_storage_after = var.cold_storage_after
        delete_after       = var.delete_after
      }
    }
  ]

  iam_role_name         = "backup-role-${local.account_id}"

}


module "backup_plan" {
  for_each = var.backup_plan_config
  source  = "./modules/terraform-aws-backup"

  vault_enabled    = each.value.vault_enabled #false
  iam_role_enabled = each.value.iam_role_enabled #false
  plan_name_suffix = each.value.plan_name_suffix #"daily_s3"
  backup_resources = each.value.backup_resources #["arn:aws:s3:::*"]
  not_resources    = each.value.not_resources
  condition_tags   = each.value.condition_tags
  rules            = each.value.rules
  iam_role_name    = "backup-role-${local.account_id}"

  depends_on       = [module.backup]
}
