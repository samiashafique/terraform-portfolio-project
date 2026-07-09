#S3 Bucket to store terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "ss-terraform-state-backend-bucket"

  tags = {
    Name = "Terraform State Bucket"
  }
}

#Enable Versioning
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {

  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

#DynamoDB table for Terraform State Locking used to prevent concurrent Terraform state modifications
resource "aws_dynamodb_table" "terraform_locks" {

  name = "terraform-locks"

  billing_mode = "PAY_PER_REQUEST"

  hash_key = "LockID" # Hash Key is now called Partition Key by AWS

  attribute {
    name = "LockID"
    type = "S"
  }
}