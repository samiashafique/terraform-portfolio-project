terraform {
  backend "s3" {
    bucket         = "ss-terraform-state-backend-bucket"
    key            = "portfolio/terraform.tfstate"
    region         = "ca-central-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}