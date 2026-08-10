terraform {
  backend "s3" {
    bucket       = "ss-terraform-state-backend-bucket"
    key          = "bootstrap/terraform.tfstate"
    region       = "ca-central-1"
    use_lockfile = true
  }
}