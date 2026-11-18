variable "name" {
  description = "IAM role name."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider (platform layer output)."
  type        = string
}

variable "oidc_issuer_hostpath" {
  description = "OIDC issuer URL without https:// (platform layer output)."
  type        = string
}

variable "namespace" {
  type    = string
  default = "default"
}

variable "service_account" {
  description = "Kubernetes ServiceAccount allowed to assume this role."
  type        = string
}

variable "policy_json" {
  description = "Inline IAM policy document (JSON) granting the role's permissions."
  type        = string
}
