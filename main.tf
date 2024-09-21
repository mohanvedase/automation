terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.35.0"
    }
  }
}


# Create a VPC
resource "aws_vpc" "myvpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    name = "myterraformvpc"
  }
}

# Create a public subnet in "myterraformvpc"
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.myvpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ca-central-1a"
}

#create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.myvpc.id
}

# Create an Elastic IP for the NAT Gateway (optional if needed later)
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# Create a NAT Gateway (optional if needed later)
resource "aws_nat_gateway" "pub_nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  depends_on    = [aws_internet_gateway.igw]
}

# Create a route table for public subnet
resource "aws_route_table" "publicRT" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# Associate route table with public subnet
resource "aws_route_table_association" "publictm" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.publicRT.id
}

# Security groups
resource "aws_security_group" "public_sg" {
  vpc_id = aws_vpc.myvpc.id
  name   = "public_sg"

  # Allow SSH and HTTP from any IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch the webserver instance in the public subnet
resource "aws_instance" "frontend" {
  ami                         = "ami-0c6d358ee9e264ff1"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet.id
  security_groups             = [aws_security_group.public_sg.id]
  associate_public_ip_address  = true  # Ensures public IP assignment
  tags = {
    Name = "frontend"
  }

  # Key pair for SSH access
  key_name = "key"
}

# Launch the database instance in the public subnet
resource "aws_instance" "backend" {
  ami                         = "ami-0c6d358ee9e264ff1"
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_subnet.id  # Now in the public subnet
  security_groups             = [aws_security_group.public_sg.id]
  associate_public_ip_address  = true  # Ensures public IP assignment
  tags = {
    Name = "backend"
  }

  # Key pair for SSH access
  key_name = "key"
}

# Output public IP of the webserver EC2 instance
output "frontend_public_ip" {
  value = aws_instance.frontend.public_ip
}

# Output public IP of the database EC2 instance
output "backend_public_ip" {
  value = aws_instance.backend.public_ip
}
