locals {
  vpc_cidr        = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.2.0/24"]
  azs             = ["us-east-1a"]
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
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH traffic
  }
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
  subnet_id              = module.vpc.public_subnets[0]
  key_name = aws_key_pair.ec2_key.key_name
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.ec2_ssm_sg.id, aws_security_group.ec2_ssh_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_instance_profile.name
  user_data = <<-EOF
              #!/bin/bash
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "Hello World from $(hostname -f)" > /var/www/html/index.html
              EOF
}
