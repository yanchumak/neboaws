# Security Group for EFS
resource "aws_security_group" "efs_sg" {
  provider = aws.us_east
  name        = "efs-sg"
  description = "Security group for EFS"
  vpc_id      = aws_vpc.main_vpc_us_east.id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "efs-sg"
  }
  depends_on = [ aws_vpc.main_vpc_us_east ]
}

resource "aws_security_group" "efs_sg_replication" {
  provider = aws.us_west
  name        = "efs-sg-replication"
  description = "Security group for EFS"
  vpc_id      = aws_vpc.main_vpc_us_west.id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "efs-sg"
  }
  depends_on = [ aws_vpc.main_vpc_us_west ]
}


# Create the primary EFS File System
resource "aws_efs_file_system" "primary_efs" {
  provider = aws.us_east
  creation_token = "my-primary-efs"
  encrypted      = true

  tags = {
    Name = "PrimaryEFS"
  }
}

# EFS Mount Targets for the Primary EFS in each availability zone
resource "aws_efs_mount_target" "primary_mount_target_a" {
  provider = aws.us_east
  file_system_id = aws_efs_file_system.primary_efs.id
  subnet_id      = aws_subnet.subnet_us_east_1a.id
  security_groups = [aws_security_group.efs_sg.id]
  depends_on = [ aws_security_group.efs_sg ]
}

# Create the IAM role for EFS replication
resource "aws_iam_role" "efs_replication_role" {
  provider = aws.us_east
  name = "EFSReplicationRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "elasticfilesystem.amazonaws.com"
      },
    }],
  })
}

# Create a custom IAM policy for EFS replication
resource "aws_iam_policy" "efs_replication_policy" {
  provider = aws.us_east
  name = "EFSReplicationCustomPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "elasticfilesystem:CreateReplicationConfiguration",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets",
          "elasticfilesystem:DescribeFileSystemPolicy",
          "elasticfilesystem:DescribeTags",
          "elasticfilesystem:DescribeLifecycleConfiguration",
          "elasticfilesystem:DescribeBackupPolicy",
          "elasticfilesystem:DescribeReplicationConfigurations"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# Attach the custom policy to the role
resource "aws_iam_policy_attachment" "efs_replication_policy_attachment" {
  provider = aws.us_east
  name       = "replication_policy_attachment"
  policy_arn = aws_iam_policy.efs_replication_policy.arn
  roles      = [aws_iam_role.efs_replication_role.name]
}


# Configure the EFS Replication Configuration
resource "aws_efs_replication_configuration" "efs_replication" {
  provider = aws.us_east
  source_file_system_id = aws_efs_file_system.primary_efs.id

  destination {
    region = "us-west-2"
  }

  lifecycle {
    ignore_changes = [source_file_system_id]
  }

  depends_on = [ aws_efs_file_system.primary_efs ]
}


# Mount Targets for the Destination EFS
resource "aws_efs_mount_target" "destination_mount_target_a" {
  provider       = aws.us_west
  file_system_id = aws_efs_replication_configuration.efs_replication.destination[0].file_system_id
  subnet_id      = aws_subnet.subnet_us_west_2a.id
  security_groups = [aws_security_group.efs_sg_replication.id]
  depends_on = [ aws_security_group.efs_sg_replication, aws_efs_replication_configuration.efs_replication ]
}

# Create IAM Role for EC2 instance to mount EFS
resource "aws_iam_role" "ec2_efs_role" {
  provider = aws.us_east
  name = "EC2EFSAccessRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
    }],
  })
}

resource "aws_iam_policy" "ec2_efs_least_privilege_policy" {
  provider = aws.us_east
  name     = "EC2EFSLeastPrivilegePolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets",
          "elasticfilesystem:CreateMountTarget",
          "elasticfilesystem:DeleteMountTarget",
          "elasticfilesystem:DescribeMountTargetSecurityGroups",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeInstances",
          "ec2:CreateNetworkInterface",
          "ec2:DeleteNetworkInterface",
          "ec2:AttachNetworkInterface"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite"
        ],
        Resource = "arn:aws:elasticfilesystem:*:*:file-system/*"
      }
    ]
  })
}


# Attach the Amazon EFS Client Managed Policy to the role
resource "aws_iam_role_policy_attachment" "ec2_efs_least_privilege_policy_attachment" {
  provider  = aws.us_east
  role      = aws_iam_role.ec2_efs_role.name
  policy_arn = aws_iam_policy.ec2_efs_least_privilege_policy.arn
}


# Create a key pair for SSH access
resource "aws_key_pair" "ec2_efs_primary_ssh_key" {
  key_name   = "ec2_efs_primary_ssh_key"
  public_key = file(var.ssh_public_key_path)
}

# Create an instance profile to attach the IAM role to the EC2 instance
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  provider = aws.us_east
  name = "EC2EFSInstanceProfile"
  role = aws_iam_role.ec2_efs_role.name
}

# EC2 Instance to access the Primary EFS
resource "aws_instance" "ec2_efs_primary" {
  provider = aws.us_east
  ami           = "ami-0738e1a0d363b9c7e" 
  instance_type = "t2.micro"

  subnet_id = aws_subnet.subnet_us_east_1a.id
  security_groups = [aws_security_group.efs_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.id
  key_name      = aws_key_pair.ec2_efs_primary_ssh_key.key_name

  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    sudo apt-get update -y
    sudo apt-get install -y nfs-common
    sudo mkdir -p /mnt/efs
    sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.primary_efs.id}.efs.us-east-1.amazonaws.com:/ /mnt/efs
  EOF


  tags = {
    Name = "EFSAccessInstance"
  }

  depends_on = [
    aws_efs_mount_target.primary_mount_target_a
  ]
}
