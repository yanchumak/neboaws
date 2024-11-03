output "instance_public_ip" {
  value = aws_instance.web.public_ip
}

output "route53_nameservers" {
  value = aws_route53_zone.idxacademy_zone.name_servers
}
