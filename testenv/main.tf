provider "aws" {
  region = "eu-west-3"  # You can change this to your preferred region
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "Main VPC"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Main IGW"
  }
}

# Create a subnet
resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "Main Subnet"
  }
}

# Create a route table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "Main Route Table"
  }
}

# Associate the route table with the subnet
resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

# Create a security group
resource "aws_security_group" "web" {
  name        = "allow_web"
  description = "Allow inbound web traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}


# Allocate Elastic IPs
resource "aws_eip" "web1" {
  domain = "vpc"
}

resource "aws_eip" "web2" {
  domain = "vpc"
}

resource "aws_eip" "web3" {
  domain = "vpc"
}

# Associate Elastic IPs with the instances
resource "aws_eip_association" "web1" {
  instance_id   = aws_instance.web[0].id
  allocation_id = aws_eip.web1.id
}

resource "aws_eip_association" "web2" {
  instance_id   = aws_instance.web[1].id
  allocation_id = aws_eip.web2.id
}

resource "aws_eip_association" "web3" {
  instance_id   = aws_instance.web[2].id
  allocation_id = aws_eip.web3.id
}

# Create three EC2 instances
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "web" {
  count         = 3
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.web.id]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Site ${count.index == 2 ? "DR" : count.index == 1 ? "B" : "A"}</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "Web Server ${count.index + 1}"
  }
}


# Output the public IPs of the instances
output "public_ips" {
  value = aws_instance.web[*].public_ip
}
