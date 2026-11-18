# IRSA roles for in-cluster service accounts. They live in the data layer because
# their permissions are scoped to data-layer resources (bucket, DB secret), and the
# cluster OIDC provider they trust comes from the platform layer's state.

data "aws_iam_policy_document" "webapp_s3_read" {
  statement {
    sid       = "ReadStaticBucket"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [module.s3_static.bucket_arn, "${module.s3_static.bucket_arn}/*"]
  }
}

module "irsa_webapp" {
  source = "../../modules/irsa_role"

  name                 = "${local.name}-webapp"
  oidc_provider_arn    = local.oidc_provider_arn
  oidc_issuer_hostpath = local.oidc_issuer_hostpath
  namespace            = "default"
  service_account      = "webapp"
  policy_json          = data.aws_iam_policy_document.webapp_s3_read.json
}

data "aws_iam_policy_document" "eso_read_db_secret" {
  statement {
    sid = "ReadDbSecret"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [module.rds.secret_arn]
  }
}

module "irsa_external_secrets" {
  source = "../../modules/irsa_role"

  name                 = "${local.name}-external-secrets"
  oidc_provider_arn    = local.oidc_provider_arn
  oidc_issuer_hostpath = local.oidc_issuer_hostpath
  namespace            = "external-secrets"
  service_account      = "external-secrets"
  policy_json          = data.aws_iam_policy_document.eso_read_db_secret.json
}
