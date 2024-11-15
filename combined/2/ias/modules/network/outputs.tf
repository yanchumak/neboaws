output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_private_subnets" {
  value = module.vpc.private_subnets
}

output "vpc_cidr_block" {
  value = module.vpc.vpc_cidr_block
}

output "vpc_database_subnet_group" {
  value = module.vpc.database_subnet_group
}

output "lb_target_group_arn" {
  value = aws_lb_target_group.this.arn
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}