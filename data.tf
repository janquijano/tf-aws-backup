data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Get Notifications API Credentials from secrets manager
data "aws_secretsmanager_secret" "notifications" {
  name                 = "nutrien-${var.environment}-platform-operations-credentials"
}

data "aws_secretsmanager_secret_version" "notifications" {
  secret_id            = data.aws_secretsmanager_secret.notifications.id
}

data "aws_secretsmanager_secret" "datadog" {
  name = "nutrien-${var.environment}-datadog-apikey"
}

data "archive_file" "init" {
  type        = "zip"
  source_file = "${path.module}/lambda/backup-restore/index.py"
  output_path = "${path.module}/lambda/backup-restore/package.zip"
}