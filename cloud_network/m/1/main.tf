
resource "aws_security_group" "ec2_http" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ec2_sg"
  }
}

resource "aws_instance" "web" {
  ami           = "ami-0738e1a0d363b9c7e"
  instance_type = "t2.micro"
  security_groups = [ aws_security_group.ec2_http.name]
  
  # Assign a public IP
  associate_public_ip_address = true

  tags = {
    Name = "idxacademy-web"
  }
}

resource "aws_route53_zone" "idxacademy_zone" {
  name = "idxacademy.xyz"
}

resource "aws_route53_record" "idxacademy_a_record" {
  zone_id = aws_route53_zone.idxacademy_zone.zone_id
  name    = ""
  type    = "A"
  ttl     = 300
  records = [aws_instance.web.public_ip]
}

