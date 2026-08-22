output "plan_role_arn" {
  value       = aws_iam_role.terraform_plan_role.arn
  description = "Copy this ARN into your GitHub Actions workflow configuration"
}

output "apply_role_arn" {
  value = aws_iam_role.terraform_apply_role.arn
  description = "Create GitHub env variable using this ARN for the apply role"
}