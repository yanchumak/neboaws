resource "aws_key_pair" "default" {
  key_name   = var.ssh_key_name
  public_key = file(var.ssh_public_key_path)
}

resource "aws_instance" "vm" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.default.key_name

  # Security group to allow SSH access
  vpc_security_group_ids = [aws_security_group.ssh.id]

  tags = {
    Name = "LinuxVM"
  }
}

# Create a security group that allows SSH access
resource "aws_security_group" "ssh" {
  name_prefix = "allow_ssh"

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
    Name = "allow_ssh"
  }
}

# Create and attach an EBS volume
resource "aws_ebs_volume" "data_disk" {
  availability_zone = aws_instance.vm.availability_zone
  size              = var.disk_size_gb

  tags = {
    Name = "DataDisk"
  }
}

resource "aws_volume_attachment" "ebs_attach" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.data_disk.id
  instance_id = aws_instance.vm.id
}
