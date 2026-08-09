output "role_arn" {
  value       = aws_iam_role.terraform_plan_role.arn
  description = "Copy this ARN into your GitHub Actions workflow configuration"
}
