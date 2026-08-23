# 1. Create the GitHub OIDC Provider in AWS
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# 2. Define the IAM Trust Policy
data "aws_iam_policy_document" "github_oidc_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

# Use token minted for AWS only    
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
# Restrict token access strictly to your specific GitHub repository
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:samiashafique/terraform-portfolio-project:pull_request"]
    }
  }
}

# 3. Create the Plan-Only IAM Role
resource "aws_iam_role" "terraform_plan_role" {
  name               = "github-terraform-plan-role"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_trust.json
}

# 4. Attach Read-Only Permissions (Prevents resource deployment/modifications)
resource "aws_iam_role_policy_attachment" "read_only" {
  role       = aws_iam_role.terraform_plan_role.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# 5. Allow the plan workflow to acquire and release the S3 native state lock.
# Terraform writes <state key>.tflock when plan starts and deletes it when plan ends.
# Scoped to that single object — the role cannot write anything else, anywhere.
resource "aws_iam_policy" "tf_state_lock" {
  name        = "terraform-plan-state-lock"
  description = "Allows the plan workflow to acquire and release the S3 state lock"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "arn:aws:s3:::ss-terraform-state-backend-bucket/portfolio/terraform.tfstate.tflock"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "tf_state_lock" {
  role       = aws_iam_role.terraform_plan_role.name
  policy_arn = aws_iam_policy.tf_state_lock.arn
}

