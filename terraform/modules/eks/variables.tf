variable "name" {
  description = "Name prefix (e.g. platlab-dev)."
  type        = string
}

variable "environment" {
  type = string
}

variable "cluster_version" {
  description = "Kubernetes version. null = latest supported by EKS at create time."
  type        = string
  default     = null
}

variable "vpc_id" {
  type = string
}

variable "app_subnet_ids" {
  description = "Private app subnets (multi-AZ) for the control plane ENIs and worker nodes."
  type        = list(string)
}

variable "node_instance_type" {
  description = "t3.small is the practical minimum for EKS system pods + the app."
  type        = string
  default     = "t3.small"
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
  description = "Average node CPU % that triggers adding a node."
  type        = number
  default     = 70
}

variable "scale_in_cpu_threshold" {
  description = "Average node CPU % below which a node is removed."
  type        = number
  default     = 40
}

variable "alb_sg_id" {
  description = "ALB security group; only it may reach the NodePort on the workers."
  type        = string
}

variable "app_node_port" {
  description = "NodePort the webapp Service exposes; the ALB target group points here."
  type        = number
  default     = 30080
}

variable "target_group_arn" {
  description = "ALB target group the worker-node ASG registers with."
  type        = string
}

variable "admin_principal_arns" {
  description = "IAM users/roles granted cluster-admin via EKS access entries (your admin user, the CI role)."
  type        = list(string)
  default     = []
}
