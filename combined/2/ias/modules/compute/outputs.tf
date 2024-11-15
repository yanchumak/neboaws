output "ecs_sg_id" {
  value = aws_security_group.ecs_sg.id
}

output "jump_host_sg_id" {
  value = aws_security_group.jump_host.id
}