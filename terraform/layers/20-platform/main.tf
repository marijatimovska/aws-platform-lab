locals {
  name       = "${var.project}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id

  cluster_admin_arns = compact(concat(
    [var.enable_ci_cluster_access ? "arn:aws:iam::${local.account_id}:role/${var.project}-github-actions" : ""],
    [var.cluster_admin_user != "" ? "arn:aws:iam::${local.account_id}:user/${var.cluster_admin_user}" : ""],
    var.extra_cluster_admin_arns,
  ))
}

module "alb" {
  source = "../../modules/alb"

  name              = local.name
  vpc_id            = local.vpc_id
  public_subnet_ids = local.public_subnet_ids

  tg_port     = var.app_node_port
  target_type = "instance"
}

module "eks" {
  source = "../../modules/eks"

  name            = local.name
  environment     = var.environment
  cluster_version = var.cluster_version
  vpc_id          = local.vpc_id
  app_subnet_ids  = local.app_subnet_ids

  node_instance_type = var.node_instance_type
  node_min_size      = var.node_min_size
  node_max_size      = var.node_max_size
  node_desired_size  = var.node_desired_size

  scale_out_cpu_threshold = var.scale_out_cpu_threshold
  scale_in_cpu_threshold  = var.scale_in_cpu_threshold

  alb_sg_id        = module.alb.alb_sg_id
  app_node_port    = var.app_node_port
  target_group_arn = module.alb.target_group_arn

  admin_principal_arns = local.cluster_admin_arns
}
