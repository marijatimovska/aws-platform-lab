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

variable "cluster_version" {
  description = "EKS Kubernetes version. null = latest."
  type        = string
  default     = null
}

variable "node_instance_type" {
  type    = string
  default = "t3.small"
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "scale_out_cpu_threshold" {
  type    = number
  default = 70
}

variable "scale_in_cpu_threshold" {
  type    = number
  default = 40
}

variable "app_node_port" {
  description = "Must match service.nodePort in apps/webapp values."
  type        = number
  default     = 30080
}

variable "enable_ci_cluster_access" {
  description = "Grant the bootstrap GitHub Actions role (<project>-github-actions) cluster-admin via an EKS access entry."
  type        = bool
  default     = true
}

variable "cluster_admin_user" {
  description = "IAM user name that gets kubectl admin (the admin user from docs/GUIDE.md section 0). Must exist. \"\" = skip."
  type        = string
  default     = "marija-admin"
}

variable "extra_cluster_admin_arns" {
  description = "Additional IAM principal ARNs for cluster-admin (e.g. an SSO role ARN if you use IAM Identity Center)."
  type        = list(string)
  default     = []
}
