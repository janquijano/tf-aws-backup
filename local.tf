locals {
  tag_defaults = {
    country                   = "AU"
    business_owner            = "Digital"
    customer_facing           = "false"
    pillar                    = "platform"
    customer_impacting        = "true"
    iac_type                  = "TF"
    iac_source                = "Agrium/tf-aws-backup"
    department-functionalarea = "Digital-AU"
    project-name              = "NaviGate"
  }

  account_id                   = data.aws_caller_identity.current.account_id

  secrets = {
    backup-restore = {
      "NOTIFICATION_API_URL": length(data.aws_secretsmanager_secret_version.notifications) == 0 ? null : "${jsondecode(data.aws_secretsmanager_secret_version.notifications.secret_string)["API_URL"]}/api/v1/slack/message"
      "NOTIFICATION_API_KEY": length(data.aws_secretsmanager_secret_version.notifications) == 0 ? null : jsondecode(data.aws_secretsmanager_secret_version.notifications.secret_string)["API_KEY"]
    }
  }
}
