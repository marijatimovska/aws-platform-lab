data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "env/${var.environment}/network.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "platform" {
  backend = "s3"

  config = {
    bucket = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "env/${var.environment}/platform.tfstate"
    region = var.region
  }
}

locals {
  vpc_id               = data.terraform_remote_state.network.outputs.vpc_id
  db_subnet_ids        = data.terraform_remote_state.network.outputs.db_subnet_ids
  cluster_sg_id        = data.terraform_remote_state.platform.outputs.cluster_security_group_id
  oidc_provider_arn    = data.terraform_remote_state.platform.outputs.oidc_provider_arn
  oidc_issuer_hostpath = data.terraform_remote_state.platform.outputs.oidc_issuer_hostpath
}
