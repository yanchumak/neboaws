# VPC in us-east-1
resource "aws_vpc" "main_vpc_us_east" {
  provider   = aws.us_east
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true 
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc-us-east"
  }
}

# VPC in us-west-2
resource "aws_vpc" "main_vpc_us_west" {
  provider   = aws.us_west
  cidr_block = "10.1.0.0/16"

  enable_dns_support   = true 
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc-us-west"
  }
}

# Subnet in us-east-1 (for the custom VPC)
resource "aws_subnet" "subnet_us_east_1a" {
  provider                = aws.us_east
  vpc_id                  = aws_vpc.main_vpc_us_east.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-us-east"
  }
}

# Subnet in us-west-2 (for the custom VPC)
resource "aws_subnet" "subnet_us_west_2a" {
  provider                = aws.us_west
  vpc_id                  = aws_vpc.main_vpc_us_west.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "subnet-us-west"
  }
}

# Create an Internet Gateway for the VPC
resource "aws_internet_gateway" "igw_east" {
  provider = aws.us_east
  vpc_id = aws_vpc.main_vpc_us_east.id

  tags = {
    Name = "main-igw"
  }
}

# Create a route table for the public subnet
resource "aws_route_table" "public_route_table" {
  provider = aws.us_east
  vpc_id = aws_vpc.main_vpc_us_east.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_east.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate the public subnet with the public route table
resource "aws_route_table_association" "public_subnet_association_east" {
  subnet_id      = aws_subnet.subnet_us_east_1a.id
  route_table_id = aws_route_table.public_route_table.id
}