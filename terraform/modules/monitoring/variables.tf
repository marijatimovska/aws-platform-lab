variable "name" {
  description = "Name prefix (e.g. platlab-dev)."
  type        = string
}

variable "region" {
  type = string
}

variable "alert_email" {
  description = "Email that receives CloudWatch alarm notifications (SNS subscription must be confirmed once by email)."
  type        = string
}

variable "alb_arn_suffix" {
  type = string
}

variable "target_group_arn_suffix" {
  type = string
}

variable "asg_name" {
  type = string
}

variable "db_identifier" {
  type = string
}
