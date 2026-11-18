variable "project" {
  description = "Short project name, lowercase. Used in resource names and the state bucket."
  type        = string
  default     = "platlab"
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "eu-central-1"
}

variable "github_repo" {
  description = "GitHub repository allowed to deploy via OIDC, as OWNER/REPO (e.g. marija/aws-platform-lab)."
  type        = string
}

variable "create_github_oidc_provider" {
  description = "Set to false if the GitHub OIDC provider already exists in this AWS account."
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email address that receives budget alerts."
  type        = string
  default     = "marijatimovska@gmail.com"
}

variable "monthly_budget_usd" {
  description = "Monthly cost budget in USD (alerts at 50%, 80%, 100% actual and 100% forecast)."
  type        = number
  default     = 30
}

variable "daily_budget_usd" {
  description = "Daily cost budget in USD. Catches forgotten running resources early."
  type        = number
  default     = 5
}
