output "plan_role_arn" {
  value       = aws_iam_role.terraform_plan_role.arn
  description = "Create GitHub repository variable using this ARN for the plan role"
}

output "apply_role_arn" {
  value       = aws_iam_role.terraform_apply_role.arn
  description = "Create GitHub repository variable using this ARN for the apply role"
}