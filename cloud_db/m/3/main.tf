locals {
  vpc_cidr        = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.2.0/24"]
  azs             = ["us-east-1a"]
  redis_port      = 6379
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.14.0"

  name               = "vpc-for-redis"
  cidr               = local.vpc_cidr
  azs                = local.azs
  public_subnets     = local.public_subnets
  private_subnets    = local.private_subnets
  enable_nat_gateway = true
  single_nat_gateway = true
}

# EC2 related resources
resource "aws_security_group" "ec2_ssm_sg" {
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTPS traffic for SSM
  }
}

resource "aws_security_group" "redis_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = local.redis_port
    to_port     = local.redis_port
    protocol    = "tcp"
    cidr_blocks = local.private_subnets
  }
}

resource "aws_security_group" "ec2_sg" {
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = local.redis_port
    to_port     = local.redis_port
    protocol    = "tcp"
    cidr_blocks = local.private_subnets
  }
}

resource "aws_elasticache_user" "default" {
  user_id       = "defaultuserid"
  user_name     = "default"
  access_string = "off -@all"
  engine        = "REDIS"
  authentication_mode {
    type = "no-password-required"
  }
}

resource "aws_elasticache_user" "user" {
  user_id       = "user"
  user_name     = "user"
  engine        = "REDIS"
  access_string = "on ~* +@all"
  authentication_mode {
    type = "iam"
  }
}

resource "aws_elasticache_user_group" "this" {
  user_group_id = "elastic-group"
  engine        = "REDIS"
  user_ids = [
    aws_elasticache_user.user.user_id,
    aws_elasticache_user.default.user_id
  ]
}


resource "aws_elasticache_subnet_group" "this" {
  name       = "elasticache-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_elasticache_replication_group" "this" {
  automatic_failover_enabled  = false
  multi_az_enabled            = false
  transit_encryption_enabled  = true
  engine                      = "redis"
  replication_group_id        = "rg1"
  description                 = "Redis Replication Group"
  node_type                   = "cache.t4g.micro"
  num_cache_clusters          = 1
  user_group_ids = [ aws_elasticache_user_group.this.user_group_id ]
  port                        = local.redis_port
  subnet_group_name           = aws_elasticache_subnet_group.this.name
  security_group_ids          = [aws_security_group.redis_sg.id]

  lifecycle {
    ignore_changes = [num_cache_clusters]
  }
}

resource "aws_elasticache_cluster" "replica" {
  count = 1

  cluster_id                 = "rg1-replica-${count.index + 1}"
  replication_group_id       = aws_elasticache_replication_group.this.id
}

# IAM Role
resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com",
        }
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "ssm_instance_profile"
  role = aws_iam_role.ec2_role.name
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Attach policy to allow access to ElastiCache
resource "aws_iam_policy" "redis_access_policy" {
  name        = "redis_access_policy"
  description = "Policy for EC2 to access ElastiCache using IAM"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "elasticache:Connect"
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:elasticache:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:replicationgroup:${aws_elasticache_replication_group.this.id}",
          "arn:aws:elasticache:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:user:${aws_elasticache_user.user.user_id}"
        ]
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "attach_redis_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.redis_access_policy.arn
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  name                   = "ec2-instance"
  ami                    = "ami-066784287e358dad1"
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.ec2_ssm_sg.id, aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_instance_profile.name
}


