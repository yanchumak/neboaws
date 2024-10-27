resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ec2_sg"
  }
  depends_on = [aws_nat_gateway.nat, aws_internet_gateway.igw]
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

# IAM Role
resource "aws_iam_role" "ssm_role" {
  name = "ssm_role"

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
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "ssm_instance_profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_instance" "nginx" {
  count         = var.instance_count
  ami           = "ami-0738e1a0d363b9c7e"
  instance_type = "t2.micro"
  subnet_id     = element([aws_subnet.private_subnet_az1.id, aws_subnet.private_subnet_az2.id], count.index % 2)
  security_groups = [aws_security_group.ec2_sg.id, aws_security_group.ssm_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile.name

  user_data = file("${path.module}/user_data.sh")

  tags = {
    Name = "nginx-instance-${count.index + 1}"
  }
}


