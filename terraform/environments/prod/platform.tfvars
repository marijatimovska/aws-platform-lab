# PROD - full HA posture. Control plane + 2 nodes bill hourly: deploy for
# demos/failover tests, destroy afterwards (docs/COST.md).
node_instance_type = "t3.small"
node_min_size      = 2
node_max_size      = 6
node_desired_size  = 2
