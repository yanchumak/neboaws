variable "name" {
  default = "web"
}

variable "environment" {
  default = "dev"
}

variable "db_username" {
  default = "admin"
  type    = string
}

variable "container_name" {
  default = "web-app-container"
  type    = string
}

variable "container_port" {
  default = 80
  type    = number
}

variable "db_name" {
  default = "webapp"
  type    = string
}

variable "db_port" {
  default = 3306
  type    = number
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "common_tags" {
  type = map(string)
  default = {
    terraform = true
    name      = "web-app"
  }
}
 