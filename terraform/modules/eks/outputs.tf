output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  description = "Worker nodes use this SG - give it to RDS as the allowed source."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "node_asg_name" {
  value = local.node_asg_name
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${aws_eks_cluster.this.name} --region <region>"
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.this.arn
}

output "oidc_issuer_hostpath" {
  description = "Issuer URL without https:// - for IRSA trust policies."
  value       = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}
