locals {
  vpc_cidr        = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.2.0/24"]
  azs             = ["us-east-1a"]
  vpn_client_cidr = "10.1.0.0/16"
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.14.0"

  name               = "vpc"
  cidr               = local.vpc_cidr
  azs                = local.azs
  public_subnets     = local.public_subnets
  private_subnets    = local.private_subnets
  enable_nat_gateway = true
  single_nat_gateway = true
}

# Security Group for VPN
resource "aws_security_group" "vpn_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_acm_certificate" "ca_cert" {
  certificate_body = file(var.ca_cert_path)
  private_key      = file(var.ca_cert_key_path)
}

resource "aws_acm_certificate" "server_cert" {
  certificate_body  = file(var.ca_server_cert_path)
  private_key       = file(var.ca_server_key_path)
  certificate_chain = file(var.ca_cert_path)
}

resource "aws_cloudwatch_log_group" "lg" {
  name = "vpn-log-group"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_stream" "ls" {
  log_group_name = aws_cloudwatch_log_group.lg.name
  name           = "vpn-log-stream"
}

# Client VPN Endpoint
resource "aws_ec2_client_vpn_endpoint" "vpn_endpoint" {
  client_cidr_block      = local.vpn_client_cidr
  server_certificate_arn = aws_acm_certificate.server_cert.arn
  split_tunnel           = true
  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = aws_acm_certificate.ca_cert.arn
  }
  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.lg.name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.ls.name
  }
  client_login_banner_options {
    banner_text = "Welcome to the VPN!"
    enabled     = true
  }
  security_group_ids = [aws_security_group.vpn_sg.id]
  vpc_id             = module.vpc.vpc_id
}

# VPN Network Association
resource "aws_ec2_client_vpn_network_association" "vpn_association" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn_endpoint.id
  subnet_id              = module.vpc.private_subnets[0]
}

# Authorization Rule
resource "aws_ec2_client_vpn_authorization_rule" "vpn_auth_rule" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.vpn_endpoint.id
  target_network_cidr    = local.vpc_cidr
  authorize_all_groups   = true
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

resource "aws_security_group" "ec2_ssh_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.private_subnets
  }
}

# IAM Role
resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
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

resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2key"
  public_key = file(var.ssh_public_key_path)
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  name                   = "ec2-instance"
  ami                    = "ami-066784287e358dad1"
  instance_type          = "t2.micro"
  subnet_id              = module.vpc.private_subnets[0]
  key_name               = aws_key_pair.ec2_key.key_name
  vpc_security_group_ids = [aws_security_group.ec2_ssm_sg.id, aws_security_group.ec2_ssh_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_instance_profile.name
}
