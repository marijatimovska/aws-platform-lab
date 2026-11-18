variable "name" {
  description = "Name prefix (e.g. platlab-dev)."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "db_subnet_ids" {
  description = "Private DB subnets (no internet route) across multiple AZs."
  type        = list(string)
}

variable "app_sg_id" {
  description = "Security group allowed to reach the DB (the EKS cluster SG)."
  type        = string
}

variable "secret_name" {
  description = "Deterministic Secrets Manager secret name (e.g. platlab/dev/db). External Secrets in the cluster references this exact name from git."
  type        = string
}

variable "engine_version" {
  type    = string
  default = "16"
}

variable "instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "multi_az" {
  description = "true = synchronous standby in a second AZ with automatic failover. Doubles instance cost - enable in prod only."
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  type    = number
  default = 1
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_username" {
  type    = string
  default = "appadmin"
}
