variable "region" {
  type        = string
  description = "AWS Region"
  default     = "ap-southeast-2"
}

variable "not_resources" {
  type        = list(string)
  description = "An array of strings that either contain Amazon Resource Names (ARNs) or match patterns of resources to exclude from a backup plan"
  default     = []
}

variable "schedule" {
  type        = string
  description = "A CRON expression specifying when AWS Backup initiates a backup job"
  default     = "cron(0 12 * * ? *)"
}

variable "start_window" {
  type        = number
  description = "The amount of time in minutes before beginning a backup. Minimum value is 60 minutes"
  default     = 60
}

variable "completion_window" {
  type        = number
  description = "The amount of time AWS Backup attempts a backup before canceling the job and returning an error. Must be at least 60 minutes greater than `start_window`"
  default     = null
}

variable "cold_storage_after" {
  type        = number
  description = "Specifies the number of days after creation that a recovery point is moved to cold storage"
  default     = 1
}

variable "delete_after" {
  type        = number
  description = "Specifies the number of days after creation that a recovery point is deleted. Must be 90 days greater than `cold_storage_after`"
  default     = 7
}

variable "backup_plan_config" {
  description = "List of backup plan configuration"
  default     = {}
}

variable "lambda_function_config" {}

variable "environment" {
  type        = string
  description = "Environment name, e.g. dev, staging, prod"
  default     = "sandbox"
}

variable "lambda_code_bucket" {
  type        = string
  description = "Bucket name where lambda conde is stored"
  default     = "my-lambda-code-store"
}

####################
# Global variables #
####################
variable "lambda_insights_layer_version" {}
variable "dd_layer_version_python" {}
variable "dd_layer_version_nodejs" {}
variable "dd_extension_version" {}
####################