resource "aws_instance" "web" {
  ami           = "ami-0738e1a0d363b9c7e"
  instance_type = "t2.micro"
  
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

