# EKS cluster + managed node group in the private app subnets.
#
# Design choice worth remembering for interviews: the ALB and its target group are
# owned by TERRAFORM (module alb), and the worker-node Auto Scaling Group is attached
# to that target group here. Pods are reached through a stable NodePort. This keeps
# `terraform destroy` 100% clean (an Ingress-created ALB would be orphaned when the
# cluster dies) and lets CloudWatch ALB alarms live in code. Migrating to the
# AWS Load Balancer Controller + Ingress is Exercise "Upgrade ideas" in BREAK-IT-LAB.md.

# ---------- Cluster IAM ----------

data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.name}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ---------- Cluster ----------

resource "aws_eks_cluster" "this" {
  name     = "${var.name}-eks"
  role_arn = aws_iam_role.cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.app_subnet_ids
    endpoint_public_access  = true # so you can kubectl from your laptop
    endpoint_private_access = true
  }

  access_config {
    authentication_mode = "API"
    # Explicit access entries only (access.tf). Implicit "creator is admin" would
    # collide with the CI role's entry whenever the pipeline creates the cluster.
    bootstrap_cluster_creator_admin_permissions = false
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# Let the ALB reach the webapp NodePort on the workers (they use the cluster security group).
resource "aws_security_group_rule" "alb_to_nodes" {
  type                     = "ingress"
  description              = "ALB to webapp NodePort"
  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  source_security_group_id = var.alb_sg_id
  protocol                 = "tcp"
  from_port                = var.app_node_port
  to_port                  = var.app_node_port
}

# ---------- Node IAM ----------

data "aws_iam_policy_document" "node_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.name}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Shell on a node without SSH keys, via SSM Session Manager.
resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ---------- Managed node group ----------

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.app_subnet_ids
  instance_types  = [var.node_instance_type]
  capacity_type   = "ON_DEMAND"

  scaling_config {
    min_size     = var.node_min_size
    max_size     = var.node_max_size
    desired_size = var.node_desired_size
  }

  update_config {
    max_unavailable = 1
  }

  lifecycle {
    # Node-level scaling policies below own desired_size after creation
    # (same pattern Cluster Autoscaler uses).
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
    aws_iam_role_policy_attachment.node_ssm,
  ]

  tags = { Name = "${var.name}-ng" }
}

locals {
  node_asg_name = aws_eks_node_group.this.resources[0].autoscaling_groups[0].name
}

# Register the worker ASG with the Terraform-owned ALB target group.
resource "aws_autoscaling_attachment" "nodes_to_tg" {
  autoscaling_group_name = local.node_asg_name
  lb_target_group_arn    = var.target_group_arn
}

# ---------- Node scaling: out at >=70% CPU, in at <=40% ----------
# (Pod-level elasticity is the HPA in the Helm chart; this handles the node layer.)

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${var.name}-node-scale-out"
  autoscaling_group_name = local.node_asg_name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 180
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${var.name}-node-scale-in"
  autoscaling_group_name = local.node_asg_name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "${var.name}-node-cpu-high"
  alarm_description   = "Average node CPU >= ${var.scale_out_cpu_threshold}% - add a node"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 2
  threshold           = var.scale_out_cpu_threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"

  dimensions = {
    AutoScalingGroupName = local.node_asg_name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out.arn]
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "${var.name}-node-cpu-low"
  alarm_description   = "Average node CPU <= ${var.scale_in_cpu_threshold}% - remove a node"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  threshold           = var.scale_in_cpu_threshold
  comparison_operator = "LessThanOrEqualToThreshold"

  dimensions = {
    AutoScalingGroupName = local.node_asg_name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in.arn]
}
