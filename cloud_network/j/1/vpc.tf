# VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "main_vpc"
  }
}

# Public Subnet 1 in AZ 1
resource "aws_subnet" "public_subnet_az1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet_az1"
  }
}

# Public Subnet 2 in AZ 2
resource "aws_subnet" "public_subnet_az2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet_az2"
  }
}

# Private Subnet 1 in AZ 1
resource "aws_subnet" "private_subnet_az1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1a"
  tags = {
    Name = "private_subnet_az1"
  }
}

# Private Subnet 2 in AZ 2
resource "aws_subnet" "private_subnet_az2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1b"
  tags = {
    Name = "private_subnet_az2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "main_igw"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public_route_table"
  }
}

# Route Table Associations for Public Subnets
resource "aws_route_table_association" "public_subnet_az1_association" {
  subnet_id      = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_az2_association" {
  subnet_id      = aws_subnet.public_subnet_az2.id
  route_table_id = aws_route_table.public_route_table.id
}

# Create an Elastic IP for the NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
  tags = {
    Name = "nat_eip"
  }
}

# Create the NAT Gateway
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_az1.id

  tags = {
    Name = "nat_gateway"
  }

  depends_on = [aws_internet_gateway.igw] 
}

# Route Table for Private Subnets
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }
}

# Route Table Associations for Private Subnets
resource "aws_route_table_association" "private_subnet_az1_association" {
  subnet_id      = aws_subnet.private_subnet_az1.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route_table_association" "private_subnet_az2_association" {
  subnet_id      = aws_subnet.private_subnet_az2.id
  route_table_id = aws_route_table.private_route_table.id
}

# NACL for Public Subnets
resource "aws_network_acl" "public_nacl" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "public_nacl"
  }
}

# Allow inbound traffic from any source on port 80 (HTTP)
resource "aws_network_acl_rule" "public_inbound_http" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

# Allow inbound traffic from any source on port 443 (HTTPS)
resource "aws_network_acl_rule" "public_inbound_https" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 101
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "public_inbound_ephemeral_ports" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 102
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}


resource "aws_network_acl_rule" "public_outbound_http" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 200
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "public_outbound_https" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 201
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

resource "aws_network_acl_rule" "public_outbound_ephemeral" {
  network_acl_id = aws_network_acl.public_nacl.id
  rule_number    = 202
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}


# NACL for Private Subnets
resource "aws_network_acl" "private_nacl" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "private_nacl"
  }
}

# Private subnet ingress
resource "aws_network_acl_rule" "private_inbound_http_public_az1" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "10.0.1.0/24"
  from_port      = 80
  to_port        = 80
}

resource "aws_network_acl_rule" "private_inbound_http_public_az2" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 101
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "10.0.2.0/24"
  from_port      = 80
  to_port        = 80
}

#For SSM and install packages
resource "aws_network_acl_rule" "private_inbound_ephemeral" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 102
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}


resource "aws_network_acl_rule" "private_outbound_ephemeral_public_az1" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 200
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "10.0.1.0/24"
  from_port      = 1024
  to_port        = 65535
}

resource "aws_network_acl_rule" "private_outbound_ephemeral_public_az2" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 201
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "10.0.2.0/24"
  from_port      = 1024
  to_port        = 65535
}

# Allow SSM
resource "aws_network_acl_rule" "private_outbound_https_to_any" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 203
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# Allow install packages
resource "aws_network_acl_rule" "private_outbound_http_to_any" {
  network_acl_id = aws_network_acl.private_nacl.id
  rule_number    = 204
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

# NACL Association with Subnets
resource "aws_network_acl_association" "public_subnet_az1_association" {
  subnet_id       = aws_subnet.public_subnet_az1.id
  network_acl_id  = aws_network_acl.public_nacl.id
}

resource "aws_network_acl_association" "public_subnet_az2_association" {
  subnet_id       = aws_subnet.public_subnet_az2.id
  network_acl_id  = aws_network_acl.public_nacl.id
}

resource "aws_network_acl_association" "private_subnet_az1_association" {
  subnet_id       = aws_subnet.private_subnet_az1.id
  network_acl_id  = aws_network_acl.private_nacl.id
}

resource "aws_network_acl_association" "private_subnet_az2_association" {
  subnet_id       = aws_subnet.private_subnet_az2.id
  network_acl_id  = aws_network_acl.private_nacl.id
}
