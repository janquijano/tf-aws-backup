terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "Nutrien"

    workspaces {
      name = "tf-backup-ci-au"
    }
  }
}