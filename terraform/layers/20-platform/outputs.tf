# Consumed by the data and observability layers, the GitOps render script, and you.

output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  value = module.eks.oidc_provider_arn
}

output "oidc_issuer_hostpath" {
  value = module.eks.oidc_issuer_hostpath
}

output "node_asg_name" {
  value = module.eks.node_asg_name
}

output "alb_dns_name" {
  value = module.alb.dns_name
}

output "alb_arn_suffix" {
  value = module.alb.alb_arn_suffix
}

output "target_group_arn_suffix" {
  value = module.alb.target_group_arn_suffix
}

output "app_url" {
  value = "http://${module.alb.dns_name}"
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.region}"
}
