output "state_bucket" {
  value = aws_s3_bucket.state.bucket
}

output "github_actions_role_arn" {
  description = "Put this in the GitHub repo variable AWS_ROLE_ARN."
  value       = aws_iam_role.github_actions.arn
}

output "region" {
  value = var.region
}
