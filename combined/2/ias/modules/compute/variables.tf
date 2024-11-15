variable "env" {
  description = "value of the environment"
  type        = string
}

variable "region" {
  description = "value of the region"
  type        = string
}

variable "app_name" {
  description = "value of the app name"
  type        = string
}

variable "app_container_port" {
  description = "value of the app container port"
  type        = number
}

variable "db_instance_address" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_secrets_arn" {
  type = string
}

variable "lb_target_group_arn" {
  type = string
}

variable "subnets" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "alb_sg_id" {
  type = string
}

variable "app_image_id" {
  type = string
}