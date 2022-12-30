resource "aws_cloudwatch_event_rule" "backup_restore" {
  count         = lookup(var.lambda_function_config, "backup-restore", 0)!=0 ? 1:0
  name        = "backup-restore-events"
  description = "Capture Backup and Restore events"

  event_pattern = <<EOF
{
  "source": ["aws.backup"],
  "detail-type": ["Restore Job State Change", "Backup Job State Change"]
}
EOF
}

resource "aws_cloudwatch_event_target" "backup_restore" {
  count         = lookup(var.lambda_function_config, "backup-restore", 0)!=0 ? 1:0
  rule      = aws_cloudwatch_event_rule.backup_restore[0].name
  target_id = "BackupRestoreLambda"
  arn       = "arn:aws:lambda:${data.aws_region.current.name}:${local.account_id}:function:${var.environment}-backup-restore"
}

resource "aws_lambda_permission" "backup_restore" {
  count         = lookup(var.lambda_function_config, "backup-restore", 0)!=0 ? 1:0
  statement_id  = "AllowExecutionFromEventBridgeRule"
  action        = "lambda:InvokeFunction"
  function_name = "${var.environment}-${var.lambda_function_config["backup-restore"].function_suffix}"
  principal     = "events.amazonaws.com"
  source_arn    = "arn:aws:events:${data.aws_region.current.name}:${local.account_id}:rule/backup-restore-*"
  depends_on = [ module.lambda_function ]
}