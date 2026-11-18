locals {
  name           = "${var.project}-${var.environment}"
  db_secret_name = "${var.project}/${var.environment}/db"
}

module "rds" {
  source = "../../modules/rds"

  name          = local.name
  vpc_id        = local.vpc_id
  db_subnet_ids = local.db_subnet_ids
  app_sg_id     = local.cluster_sg_id
  secret_name   = local.db_secret_name

  instance_class        = var.db_instance_class
  multi_az              = var.db_multi_az
  backup_retention_days = var.db_backup_retention_days
}

module "s3_static" {
  source = "../../modules/s3_static"

  name        = local.name
  bucket_name = "${local.name}-static-${data.aws_caller_identity.current.account_id}"
}
