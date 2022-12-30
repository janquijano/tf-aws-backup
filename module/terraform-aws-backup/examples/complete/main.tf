
module "backup" {
  source = "../.."

  backup_resources = [""]
  not_resources    = var.not_resources

  rules = [
    {
      name              = "sample-daily"
      schedule          = var.schedule
      start_window      = var.start_window
      completion_window = var.completion_window
      lifecycle = {
        cold_storage_after = var.cold_storage_after
        delete_after       = var.delete_after
      }
    }
  ]

}

