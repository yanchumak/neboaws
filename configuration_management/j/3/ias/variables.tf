variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "ssh_key_name" {
  description = "The name of the SSH key to use for the EC2 instance"
  default = "Ansible ssh key"
}

variable "ssh_public_key_path" {
  description = "Path to the public SSH key"
}

variable "ami_id" {
  description = "AMI ID to use for the EC2 instance"
  default     = "ami-0b0ea68c435eb488d" 
}

variable "disk_size_gb" {
  description = "Size of the EBS volume in GB"
  default     = 8
}
