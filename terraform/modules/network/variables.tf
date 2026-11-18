variable "name" {
  description = "Name prefix for all VPC resources (e.g. platlab-dev)."
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of availability zones to spread subnets across."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3 for a highly available design."
  }
}

variable "single_nat_gateway" {
  description = "true = one shared NAT gateway (cheaper, lab default). false = one NAT gateway per AZ (true HA for outbound traffic, ~double/triple NAT cost)."
  type        = bool
  default     = true
}
