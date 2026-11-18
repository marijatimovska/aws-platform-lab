vpc_cidr           = "10.30.0.0/16"
az_count           = 2
single_nat_gateway = true # set false for per-AZ NAT (true HA egress, +cost)
