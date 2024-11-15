output "db_instance_address" {
  value = module.mysql_db.db_instance_address
}

output "db_port" {
  value = module.mysql_db.db_instance_port
}

output "db_instance_master_user_secret_arn" {
  value = module.mysql_db.db_instance_master_user_secret_arn

}