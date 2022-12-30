# Lambda common policy
data "aws_iam_policy" "common_lambda_policy" {
  name = "${var.environment}-lambda-common-policy"
}

resource "aws_iam_role_policy_attachment" "backup" {
  for_each   = module.lambda_function
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupFullAccess"
  role       = each.value.lambda_role_name
}