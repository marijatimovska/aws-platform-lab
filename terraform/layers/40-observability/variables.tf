variable "project" {
  type    = string
  default = "platlab"
}

variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be one of: dev, qa, prod."
  }
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

variable "alert_email" {
  type    = string
  default = "marijatimovska@gmail.com"
}
