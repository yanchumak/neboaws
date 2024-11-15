# ECR Repository
resource "aws_ecr_repository" "main" {
  name         = "ecr-repo-${var.env}"
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }
  tags = {
    environment = var.env
  }
}

resource "aws_ecr_lifecycle_policy" "ecr_policy" {
  repository = aws_ecr_repository.main.name
  policy     = local.ecr_policy
}

locals {
  ecr_policy = jsonencode({
    "rules" : [
      {
        "rulePriority" : 1,
        "description" : "Expire images older than 7 days",
        "selection" : {
          "tagStatus" : "any",
          "countType" : "sinceImagePushed",
          "countUnit" : "days",
          "countNumber" : 7
        },
        "action" : {
          "type" : "expire"
        }
      }
    ]
  })
}

module "rds_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "rds-sg-${var.env}"
  description = "MySQL security group"
  vpc_id      = var.vpc_id

  ingress_with_source_security_group_id = [
    for sg_id in var.db_allowed_sg_ids : {
      from_port   = var.db_port
      to_port     = var.db_port
      protocol    = "tcp"
      description = "Allow MySQL access from ${sg_id}"
      source_security_group_id = sg_id
    }
  ]

  tags = {
    environment = var.env
  }
}

module "mysql_db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.10.0"

  identifier = "mysql-db-${var.env}"

  engine               = "mysql"
  engine_version       = "8.0"
  family               = "mysql8.0"
  major_engine_version = "8.0"
  instance_class       = var.db_instance_class

  allocated_storage     = 5
  max_allocated_storage = 10

  db_name                     = var.db_name
  username                    = var.db_username
  manage_master_user_password = true
  port                        = var.db_port

  multi_az               = false
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [module.rds_sg.security_group_id]

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["audit", "general"]

  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = true
  tags = {
    environment = var.env
  }
}
