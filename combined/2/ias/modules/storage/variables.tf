variable "env" {
  description = "value of the environment"
  type        = string
}

variable "app_name" {
  description = "value of the app name"
  type        = string
}

variable "db_port" {
  description = "value of the db port"
  type        = number
}

variable "db_name" {
  description = "value of the db name"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "db_subnet_group_name" {
  type = string

}

variable "db_allowed_sg_ids" {
  description = "List of security group IDs allowed to access DB"
  type        = list(string)
  default     = []
}

variable "db_instance_class" {
  description = "DB instance class"
  type        = string
}