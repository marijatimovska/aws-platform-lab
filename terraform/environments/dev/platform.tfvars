# DEV - 2 x t3.small is the practical floor: a t3.small fits only ~11 pods
# (ENI/IP limit) and ArgoCD + External Secrets + system pods + the app need ~16.
# (Raising that limit with VPC CNI prefix delegation is a BREAK-IT-LAB upgrade.)
node_instance_type = "t3.small"
node_min_size      = 2
node_max_size      = 3
node_desired_size  = 2
