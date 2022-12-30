
# Create the temporary package.zip
resource "aws_s3_bucket_object" "package" {
    for_each = var.lambda_function_config
    bucket = var.lambda_code_bucket
    acl    = "private"
    key    = "${each.value.function_suffix}/latest/package.zip"
    source = "${path.module}/lambda/backup-restore/package.zip"

    lifecycle {
      ignore_changes = [key,source]
    }

  depends_on = [
    data.archive_file.init
  ]

}

