output "rds_endpoint" {
  value = module.rds.endpoint
}

output "db_identifier" {
  value = module.rds.db_identifier
}

output "db_secret_name" {
  description = "Deterministic name the ExternalSecret manifest references."
  value       = module.rds.secret_name
}

output "db_secret_arn" {
  value = module.rds.secret_arn
}

output "static_bucket" {
  value = module.s3_static.bucket_name
}

output "static_site_url" {
  value = module.s3_static.website_url
}

output "webapp_irsa_role_arn" {
  value = module.irsa_webapp.role_arn
}

output "external_secrets_irsa_role_arn" {
  value = module.irsa_external_secrets.role_arn
}
