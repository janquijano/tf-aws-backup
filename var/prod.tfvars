backup_plan_config = {
    daily_ec2 = {
        vault_enabled    = false
        iam_role_enabled = false
        plan_name_suffix = "daily_ec2"
        backup_resources = ["arn:aws:ec2:*:*:instance/*"]
        not_resources    = ["arn:aws:ec2:*:*:volume/*"]
        condition_tags   = [
            {
                type  = ["string_equals"]
                key   = "aws:ResourceTag/backup-schedule"
                value = "daily-ec2"
            }
        ]
        rules            = [
            {
                name              = "593167004615-daily-ec2"
                schedule          = "cron(0 12 * * ? *)"
                start_window      = 60
                completion_window = 120
                lifecycle = {
                    # cold_storage_after = 1
                    delete_after       = 7
                }
            }
        ]
    },

    daily_rds = {
        vault_enabled    = false
        iam_role_enabled = false
        plan_name_suffix = "daily_rds"
        backup_resources = ["arn:aws:rds:*:*:cluster:*"]
        not_resources    = []
        condition_tags   = [
            {
                type  = ["string_equals"]
                key   = "aws:ResourceTag/backup-schedule"
                value = "daily-rds"
            }
        ]
        rules            = [
            {
                name              = "593167004615-daily-rds"
                schedule          = "cron(0 14 * * ? *)"
                start_window      = 60
                completion_window = 180
                lifecycle = {
                    # cold_storage_after = 1
                    delete_after       = 7
                }
                enable_continuous_backup = true
            }
        ]
    },

    #daily_s3 = {
    #    vault_enabled    = false
    #    iam_role_enabled = false
    #    plan_name_suffix = "daily_s3"
    #    backup_resources = ["arn:aws:s3:::*"]
    #    not_resources    = []
    #    condition_tags   = [
    #        {
    #            type  = ["string_equals"]
    #            key   = "aws:ResourceTag/backup-schedule"
    #            value = "daily-s3"
    #        }
    #    ]
    #    rules            = [
    #        {
    #            name              = "593167004615-daily-s3"
    #            schedule          = "cron(0 15 * * ? *)"
    #            start_window      = 60
    #            completion_window = 180
    #            lifecycle = {
    #                # cold_storage_after = 1
    #                delete_after       = 7
    #            }
    #        }
    #    ]
    #}
}

environment = "prod"
lambda_function_config = {
    backup-restore = {
          datadog_enabled       = true
          function_suffix       = "backup-restore"
          handler               = "index.handler"
          runtime_version       = "python3.8"
          memory_size           = "512"
          timeout               = "180"
          environment_variables = {}
          policy_statements     = {
                iam_pass_role = {
                    effect    = "Allow",
                    actions   = [
                        "iam:PassRole",
                        "ec2:DeleteVolume",
                        "ec2:TerminateInstances",
                        "rds:DeleteDbInstance",
                        "rds:DeleteDBCluster",
                        "elasticfilesystem:DeleteFileSystem",
                        "dynamodb:DeleteTable"
                    ],
                    resources = ["*"]
                },
                tagging = {
                    effect    = "Allow",
                    actions   = [
                        "rds:ListTagsForResource",
                        "ec2:DescribeTags",
                        "elasticfilesystem:DescribeTags",
                        "elasticfilesystem:ListTagsForResource",
                        "dynamodb:ListTagsForResource",
                        "s3:GetBucketTagging"
                    ],
                    resources = ["*"]
                }
          }
          create_in_vpc         = false
    }
}
