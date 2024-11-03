resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main_vpc.id
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

resource "aws_security_group" "ssm_sg" {
  vpc_id = aws_vpc.main_vpc.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTPS traffic for SSM
  }

  tags = {
    Name = "ssm_sg"
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

resource "aws_launch_template" "app_template" {
  name          = "app-launch-template"
  image_id      = "ami-066784287e358dad1"
  instance_type = "t2.micro"

  vpc_security_group_ids = [ 
    aws_security_group.ec2_sg.id,
    aws_security_group.ssm_sg.id 
  ]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_instance_profile.name
  }

  monitoring {
    enabled = true
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y stress-ng
    yum install -y amazon-cloudwatch-agent
    cat <<EOT > /opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-agent-config.json
    {
      "metrics": {
        "metrics_collected": {
          "cpu": {
            "measurement": [
             {"name": "cpu_usage_idle", "rename": "CPUUsageIdle", "unit": "Percent"},
              {"name": "cpu_usage_user", "rename": "CPUUsageUser", "unit": "Percent"},
              {"name": "cpu_usage_system", "rename": "CPUUsageSystem", "unit": "Percent"},
              {"name": "cpu_usage_active", "rename": "CPUUtilization", "unit": "Percent"}
            ],
            "metrics_collection_interval": 30
          }
        }
      }
    }
    EOT
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config \
      -m ec2 \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/cloudwatch-agent-config.json \
      -s
    systemctl start amazon-cloudwatch-agent
    systemctl enable amazon-cloudwatch-agent
  EOF
  )
}
