# 1. Define the IAM Trust Policy for Apply
data "aws_iam_policy_document" "github_oidc_trust_apply" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # Rejects a token GitHub minted for a different service.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Pins the repo AND the prod environment. Approval happens before the job starts
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:samiashafique/terraform-portfolio-project:environment:prod"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:ref"
      values   = ["refs/heads/main"]
    }
  }
}

# 2. Create the Apply Iam Role
resource "aws_iam_role" "terraform_apply_role" {
  name               = "github-terraform-apply-role"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_trust_apply.json
}

# 3a. Broad read access for terraform's refresh phase.
# Deliberate compromise, carried over from the plan role: scoping reads means
# enumerating every Get*/List*/Describe* the AWS provider calls during refresh.
# Follow-up is to derive that list from CloudTrail and replace this attachment.
resource "aws_iam_role_policy_attachment" "apply_read_only" {
  role       = aws_iam_role.terraform_apply_role.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# 3b. Every write this role is permitted to make. Nothing else in the account
# is writable by it.
resource "aws_iam_policy" "terraform_apply_writes" {
  name        = "terraform-apply-writes"
  description = "Writes required by terraform apply: portfolio bucket, CloudFront, and its own state file"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Bucket-level operations only, pinned to the one bucket this config manages.
      {
        Sid    = "PortfolioBucketWrites"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:PutBucketTagging",
          "s3:PutBucketOwnershipControls",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutEncryptionConfiguration",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy"
        ]
        Resource = "arn:aws:s3:::ss-portfolio-website-bucket"
      },

      {
        Sid    = "CloudFrontWrites"
        Effect = "Allow"
        Action = [
          "cloudfront:CreateDistribution",
          "cloudfront:UpdateDistribution",
          "cloudfront:DeleteDistribution",
          "cloudfront:CreateOriginAccessControl",
          "cloudfront:UpdateOriginAccessControl",
          "cloudfront:DeleteOriginAccessControl",
          "cloudfront:TagResource",
          "cloudfront:UntagResource"
        ]
        Resource = "*"
      },
      {
        Sid    = "TerraformStateWrites"
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::ss-terraform-state-backend-bucket/portfolio/terraform.tfstate",
          "arn:aws:s3:::ss-terraform-state-backend-bucket/portfolio/terraform.tfstate.tflock"
        ]
      },
      {
        Sid    = "DeleteTerraformStateLock"
        Effect = "Allow"
        Action = [
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::ss-terraform-state-backend-bucket/portfolio/terraform.tfstate.tflock"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "terraform_apply_writes" {
  role       = aws_iam_role.terraform_apply_role.name
  policy_arn = aws_iam_policy.terraform_apply_writes.arn
}
