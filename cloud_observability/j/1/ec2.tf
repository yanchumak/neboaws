# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.14.0"

  name               = "monitored-vpc"
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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2_sg"
  }
}

# IAM assume Role
resource "aws_iam_role" "ec_assume_role" {
  name = "ec2_assume_role"

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

# Attach SSM policy to role
resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.ec_assume_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch Agent policy to role
resource "aws_iam_role_policy_attachment" "cloudwatch_policy_attachment" {
  role       = aws_iam_role.ec_assume_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2.instance_profile"
  role = aws_iam_role.ec_assume_role.name
}

# EC2 Instance with User Data for CloudWatch Agent
module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "5.7.1"

  name                        = "monitored-instance"
  ami                         = "ami-066784287e358dad1"
  instance_type               = "t2.micro"
  monitoring                  = true #For detaied monitoring
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name
  associate_public_ip_address = true

  user_data = file("${path.module}/ec2_user_data.sh")

  tags = {
    Name = "MonitoredInstance"
  }
}

# CloudWatch Dashboard for EC2 monitoring, referencing the JSON file
resource "aws_cloudwatch_dashboard" "ec2_dashboard" {
  dashboard_name = "EC2-Monitoring-Dashboard"

  # Import JSON file content for the dashboard body
  dashboard_body = file("ec2_monitoring_dashboard.json")
}


# CloudWatch Dashboard and Alarm for EC2 Instance
module "cloudwatch_dashboard" {
  source  = "terraform-aws-modules/cloudwatch/aws//modules/metric-alarm"
  version = "5.6.1"


  alarm_name          = "HighCPUAlarm"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  comparison_operator = "GreaterThanThreshold"
  threshold           = 70
  evaluation_periods  = 2
  period              = 30
  statistic           = "Average"
  dimensions          = { InstanceId = module.ec2_instance.id }
  alarm_description   = "This alarm monitors high CPU usage on the EC2 instance."

  tags = {
    Environment = "production"
  }
}