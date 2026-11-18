variable "name" {
  description = "Name prefix (e.g. platlab-dev)."
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "public_subnet_ids" {
  description = "Public subnets (one per AZ) the ALB is deployed into."
  type        = list(string)
}

variable "health_check_path" {
  type    = string
  default = "/health"
}

variable "tg_port" {
  description = "Port the target group forwards to. 80 for plain instances, a NodePort (e.g. 30080) for Kubernetes workers."
  type        = number
  default     = 80
}

variable "target_type" {
  type    = string
  default = "instance"
}
