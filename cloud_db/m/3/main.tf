locals {
  vpc_cidr        = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.2.0/24"]
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.14.0"

  name               = "vpc-for-redis"
  cidr               = local.vpc_cidr
  azs                = ["us-east-1a"]
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

# EC2 related resources
resource "aws_security_group" "ec2_redis_sg" {
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [local.private_subnets[0]]
  }
}



# Redis related resources
# Create an ElastiCache user with IAM Authentication
resource "aws_elasticache_user" "this" {
  user_id       = "user"
  user_name     = "user"
  engine        = "REDIS"
  access_string = "on ~* +@all"
  authentication_mode {
    type = "iam"
  }
}

# Create a user group and associate the user
resource "aws_elasticache_user_group" "this" {
  user_group_id = "elastic-group"
  engine        = "REDIS"
  user_ids      = [aws_elasticache_user.this.user_id, "default"]
}

module "elasticache" {
  source  = "terraform-aws-modules/elasticache/aws"
  version = "1.3.0"

  cluster_id               = "redis1"
  create_cluster           = true
  create_replication_group = false
  cluster_mode             = false

  engine_version = "7.1"
  node_type      = "cache.t4g.small"

  maintenance_window = "sun:05:00-sun:09:00"
  apply_immediately  = true

  # Security group
  vpc_id = module.vpc.vpc_id

  security_group_rules = {
    ingress_vpc = {
      description = "VPC traffic"
      cidr_ipv4   = local.private_subnets[0]
    }
  }

  user_group_ids = [aws_elasticache_user_group.this.id]

  # Subnet Group
  subnet_ids = module.vpc.private_subnets

  # Parameter Group
  create_parameter_group = true
  parameter_group_family = "redis7"
  parameters = [
    {
      name  = "latency-tracking"
      value = "yes"
    }
  ]
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
        },
      },
    ],
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

# Attach policy to allow access to ElastiCache
resource "aws_iam_policy" "redis_access_policy" {
  name        = "redis_access_policy"
  description = "Policy for EC2 to access ElastiCache using IAM"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["elasticache:Connect", "elasticache:Describe*"],
        Effect   = "Allow",
        Resource = module.elasticache.cluster_arn
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
  vpc_security_group_ids = [aws_security_group.ec2_ssm_sg.id, aws_security_group.ec2_redis_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_instance_profile.name
}


