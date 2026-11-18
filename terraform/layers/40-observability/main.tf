locals {
  name = "${var.project}-${var.environment}"
}

module "monitoring" {
  source = "../../modules/monitoring"

  name        = local.name
  region      = var.region
  alert_email = var.alert_email

  alb_arn_suffix          = data.terraform_remote_state.platform.outputs.alb_arn_suffix
  target_group_arn_suffix = data.terraform_remote_state.platform.outputs.target_group_arn_suffix
  asg_name                = data.terraform_remote_state.platform.outputs.node_asg_name
  db_identifier           = data.terraform_remote_state.data.outputs.db_identifier
}
