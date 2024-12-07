output "main_vpc_us_west" {
  value = aws_vpc.main_vpc_us_west
}

output "main_vpc_us_east" {
  value = aws_vpc.main_vpc_us_east
}

output "instance_public_ip" {
  value = aws_instance.ec2_efs_primary.public_ip
}

data "aws_caller_identity" "current" {}

output "readonly_user_password" {
  value     = aws_iam_user_login_profile.readonly_user_profile.password
  sensitive = true
}

output "readwrite_user_password" {
  value     = aws_iam_user_login_profile.readwrite_user_profile.password
  sensitive = true
}

output "user_console_url" {
  value = "https://signin.aws.amazon.com/console/${data.aws_caller_identity.current.account_id}"
}