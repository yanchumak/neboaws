terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.65.0"
    }
  }
  required_version = ">= 1.8.5"
}

provider "aws" {
  region = "us-east-1"
}

# Generate a password for the database
resource "random_password" "db_password" {
  length           = 16
  special          = false
  override_special = "_"
}

# Security Group for RDS allowing inbound access to MySQL (port 3306)
resource "aws_security_group" "rds_sg" {
  name_prefix = "rds-sg"

  ingress {
    description = "Allow MySQL access"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["YOUR_LOCAL_IP/32"]  # Replace with your local IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# RDS MySQL Instance
resource "aws_db_instance" "mysql" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "8.0"  # specify MySQL version
  instance_class       = "db.t3.small"
                   = "mydatabase"
  username             = "admin"
  password             = random_password.db_password.result
  parameter_group_name = "default.mysql8.0"
  publicly_accessible  = true
  skip_final_snapshot  = false
  deletion_protection  = true
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
}
