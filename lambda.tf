module "lambda_function" {
  for_each                  = var.lambda_function_config

  source  = "terraform-aws-modules/lambda/aws"
  version = "2.34.1"

  publish                   = false
  function_name             = "nutrien-${var.environment}-${each.value.function_suffix}"
  handler                   = each.value.datadog_enabled == false ? each.value.handler : substr(each.value.runtime_version, 0, 6) == "python" ? "datadog_lambda.handler.handler" : "/opt/nodejs/node_modules/datadog-lambda-js/handler.handler"
  runtime                   = each.value.runtime_version
  memory_size               = each.value.memory_size
  timeout                   = each.value.timeout
  cloudwatch_logs_retention_in_days = 90
  create_package            = false
  s3_existing_package       = {
    bucket = var.lambda_code_bucket
    key = "${each.value.function_suffix}/latest/package.zip"
    version_id = null
  }

  # policies
  attach_policies           = true  
  number_of_policies        = 1 // for common policy
  policies                  = ["${data.aws_iam_policy.common_lambda_policy.arn}"]

  attach_policy_statements = each.value.policy_statements == {} ? false : true
  policy_statements = each.value.policy_statements

  # networking
  vpc_subnet_ids         = each.value.create_in_vpc == true ? each.value.subnet_ids : null
  vpc_security_group_ids = each.value.create_in_vpc == true ? each.value.security_group_ids : null
  attach_network_policy  = each.value.create_in_vpc == true ? true : false

  # environment variables to pass to lambda function
  environment_variables     = merge({
    "DD_ENV" = each.value.datadog_enabled == true ? var.environment : null
    "DD_SERVICE" = each.value.datadog_enabled == true ? "nutrien-${var.environment}-${each.value.function_suffix}" : null
    "DD_LAMBDA_HANDLER" = each.value.datadog_enabled == true ? each.value.handler : null
    "DD_SITE" = each.value.datadog_enabled == true ? "datadoghq.com" : null
    "DD_API_KEY_SECRET_ARN" = each.value.datadog_enabled == true ? data.aws_secretsmanager_secret.datadog.arn : null
    "DD_TRACE_ENABLED" = each.value.datadog_enabled == true ? "true" : null
    "DD_MERGE_XRAY_TRACES" = each.value.datadog_enabled == true ? "true" : null
    "DD_LOGS_INJECTION" = each.value.datadog_enabled == true ? "true" : null
  }, each.value.environment_variables, lookup(local.secrets, each.value.function_suffix, {}))

  # tracing
  tracing_mode = "Active"
  attach_tracing_policy = true

  # lambda insights and datadog layers
  layers = each.value.datadog_enabled == false ? [
    "arn:aws:lambda:${data.aws_region.current.name}:580247275435:layer:LambdaInsightsExtension:${var.lambda_insights_layer_version}"
  ] : substr(each.value.runtime_version, 0, 6) == "python" ? [
    "arn:aws:lambda:${data.aws_region.current.name}:580247275435:layer:LambdaInsightsExtension:${var.lambda_insights_layer_version}",
    "arn:aws:lambda:${data.aws_region.current.name}:464622532012:layer:Datadog-Python38:${var.dd_layer_version_python}",
    "arn:aws:lambda:${data.aws_region.current.name}:464622532012:layer:Datadog-Extension:${var.dd_extension_version}"
  ] : [
    "arn:aws:lambda:${data.aws_region.current.name}:580247275435:layer:LambdaInsightsExtension:${var.lambda_insights_layer_version}",
    "arn:aws:lambda:${data.aws_region.current.name}:464622532012:layer:Datadog-Node16-x:${var.dd_layer_version_nodejs}",
    "arn:aws:lambda:${data.aws_region.current.name}:464622532012:layer:Datadog-Extension:${var.dd_extension_version}"
  ]

  depends_on = [
    aws_s3_bucket_object.package
  ]

  tags = local.tag_defaults

}
