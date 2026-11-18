data "terraform_remote_state" "platform" {
  backend = "s3"

  config = {
    bucket = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "env/${var.environment}/platform.tfstate"
    region = var.region
  }
}

data "terraform_remote_state" "data" {
  backend = "s3"

  config = {
    bucket = "${var.project}-tfstate-${data.aws_caller_identity.current.account_id}"
    key    = "env/${var.environment}/data.tfstate"
    region = var.region
  }
}
