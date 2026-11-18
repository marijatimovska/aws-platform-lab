# PostgreSQL on RDS, private DB subnets, reachable only from the cluster SG.
#
# Credentials pattern: Terraform generates the password and writes a connection
# secret under a DETERMINISTIC name (platlab/<env>/db). That stable name is what
# the ExternalSecret manifest in git references - the whole chain
# Secrets Manager -> External Secrets Operator -> k8s Secret -> pod env works
# without ever committing a credential.
#
# TRADE-OFF (worth saying in interviews): the password exists in Terraform state
# (encrypted S3 bucket). The alternative - RDS-managed master passwords
# (manage_master_user_password) - keeps it out of state but generates a random
# secret name, which breaks the GitOps reference. Production answer: RDS-managed
# secret + rotation, with the app reading the secret ARN from config, or IAM
# database authentication. See docs/BREAK-IT-LAB.md upgrades.

resource "random_password" "master" {
  length  = 24
  special = false # avoid chars that complicate URL-encoding in connection strings
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-db-subnets"
  subnet_ids = var.db_subnet_ids

  tags = { Name = "${var.name}-db-subnets" }
}

resource "aws_security_group" "db" {
  name_prefix = "${var.name}-db-"
  description = "RDS: PostgreSQL from the cluster SG only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.app_sg_id]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${var.name}-db-sg" }
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name}-db"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.master.result

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period  = var.backup_retention_days
  delete_automated_backups = true

  # Lab settings: allow clean `terraform destroy`. In production:
  # deletion_protection = true, skip_final_snapshot = false.
  skip_final_snapshot = true
  deletion_protection = false

  apply_immediately = true

  tags = { Name = "${var.name}-db" }
}

resource "aws_secretsmanager_secret" "db" {
  name        = var.secret_name
  description = "Connection details for ${var.name}-db (read in-cluster via External Secrets)"

  # Lab: delete immediately on destroy so tomorrow's apply can reuse the name.
  # Production would keep the default 30-day recovery window.
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.master.result
    host     = aws_db_instance.this.address
    port     = tostring(aws_db_instance.this.port)
    dbname   = var.db_name
  })
}
