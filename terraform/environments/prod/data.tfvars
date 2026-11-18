# Multi-AZ roughly doubles RDS cost - prod is for failover demos.
db_instance_class        = "db.t4g.micro"
db_multi_az              = true
db_backup_retention_days = 7
