# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.14.0"

  name               = "vpc"
  cidr               = "10.0.0.0/16"
  azs                = ["us-east-1a"]
  public_subnets     = ["10.0.1.0/24"]
  private_subnets    = ["10.0.2.0/24"]
  enable_nat_gateway = true
  single_nat_gateway = true

  tags = {
    Environment = "production"
  }
}

resource "aws_security_group" "ec2_sg" {
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["130.41.150.171/32"]
  }

  tags = {
    Name = "ec2_sg"
  }
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2key"
  public_key = file(var.ssh_public_key_path)
}

# EC2 Instance with User Data for CloudWatch Agent
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  name                        = "ec2-instance"
  ami                         = "ami-0887e1d5e322290cf"
  instance_type               = "t2.micro"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true
  key_name = aws_key_pair.ec2_key.key_name

  tags = {
    Name = "NeboTask"
  }
}
