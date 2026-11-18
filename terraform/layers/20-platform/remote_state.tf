# Cross-layer wiring: read the network layer's outputs from its own state file.
# Layers stay independently applyable/destroyable, but share one source of truth.

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "env/${var.environment}/network.tfstate"
    region = var.region
  }
}

locals {
  vpc_id            = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids = data.terraform_remote_state.network.outputs.public_subnet_ids
  app_subnet_ids    = data.terraform_remote_state.network.outputs.app_subnet_ids
}
