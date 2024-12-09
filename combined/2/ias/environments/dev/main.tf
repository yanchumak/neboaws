provider "aws" {
  region = var.region
}

locals {
  env                = "dev"
  region             = var.region
  vpc_cidr           = "10.0.0.0/16"
  db_instance_class  = "db.t3.small"
  db_port            = 3306
  db_name            = "appdb"
  app_name           = "webapp"
  app_container_port = 80
  app_image_id       = "nginx:latest"
}

module "network" {
  source = "../../modules/network"

  vpc_name = "${local.app_name}-vpc"
  env      = local.env
  vpc_cidr = local.vpc_cidr
}

module "storage" {
  source = "../../modules/storage"

  env                  = local.env
  app_name             = local.app_name
  db_instance_class    = local.db_instance_class
  db_port              = local.db_port
  db_name              = local.db_name
  vpc_id               = module.network.vpc_id
  db_allowed_sg_ids    = [ module.compute.ecs_sg_id, module.compute.jump_host_sg_id ]
  db_subnet_group_name = module.network.vpc_database_subnet_group
}

module "compute" {
  source = "../../modules/compute"

  app_image_id        = local.app_image_id
  app_container_port  = local.app_container_port
  db_port             = local.db_port
  env                 = local.env
  region              = local.region
  app_name            = local.app_name
  db_secrets_arn      = module.storage.db_instance_master_user_secret_arn
  db_instance_address = module.storage.db_instance_address
  lb_target_group_arn = module.network.lb_target_group_arn
  vpc_id              = module.network.vpc_id
  subnets             = module.network.private_subnets
  alb_sg_id           = module.network.alb_sg_id
}
