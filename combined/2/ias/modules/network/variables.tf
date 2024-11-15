variable "vpc_name" {
  description = "value of the vpc name"
  type        = string
}

variable "vpc_cidr" {
  description = "value of the vpc cidr"
  type        = string
}

variable "env" {
  description = "value of the environment"
  type        = string
}

variable "alb_ingress_port" {
  description = "value of the alb ingress port"
  type        = number
  default     = 80
}
