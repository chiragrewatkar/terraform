resource "aws_vpc" "vpc" {
  cidr_block = var.public.vpc
  tags = {

    Name = var.tags
  }

}

resource "aws_subnet" "public-1" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.public.public-1

  tags = {
    Name = "public-sub-1"
  }

}

resource "aws_subnet" "public-2" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.public.public-2

  tags = {
    Name = "public-subnet-2"
  }

}

resource "aws_subnet" "private-1" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.public.private-1

  tags = {
    Name = "private-subnet-1"
  }

}
resource "aws_subnet" "private-2" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.public.private-2

  tags = {
    Name = "private-subnet-2"
  }

}
resource "aws_subnet" "private-3" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.public.private-3

  tags = {
    Name = "private-subnet-3"
  }

}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "igw-vpc"
  }

}

resource "aws_route_table" "route-vpc" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = var.public.route
    gateway_id = aws_internet_gateway.igw.id

  }
}
resource "aws_route_table_association" "route1" {
  subnet_id      = aws_subnet.public-1.id
  route_table_id = aws_route_table.route-vpc.id
}

resource "aws_route_table_association" "route2" {
  subnet_id      = aws_subnet.public-2.id
  route_table_id = aws_route_table.route-vpc.id
}

 data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "chirag" {
  ami             = "ami-052efd3df9dad4825"
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.chirag-key.id
  security_groups = [aws_security_group.chirag-sg.id]
  subnet_id = aws_subnet.public-1.id
  associate_public_ip = true
  tags = {
    Name = "chirag-1"
  }
}
resource "tls_private_key" "chirag-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "chirag-key" {
  key_name   = "chirag-key"
  public_key = tls_private_key.chirag-key.public_key_openssh
}

resource "aws_security_group" "chirag-sg" {
  name        = "chirag-sg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = { 
    Name = "sg"
  }
}

resource "aws_launch_configuration" "ami-1" {
  name_prefix = "ami-1"

  image_id = "ami-052efd3df9dad4825" # Amazon Linux 2 AMI (HVM), SSD Volume Type
  instance_type = "t2.micro"
  key_name = "chirag-key"

  security_groups = [ aws_security_group.chirag-sg.id ]
  associate_public_ip_address = true

  user_data = <<EOF
#! /bin/bash
sudo apt-get update -y
sudo apt-get install apache2 -y
sudo systemctl start apache2
echo "hello cloudblitz!" > /var/www/html/index.html
sudo systemctl restart apache2
EOF

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_elb" "chirag-sg" {
  name = "chirag-sg"
  security_groups = [
    aws_security_group.chirag-sg.id
  ]
  subnets = [
    aws_subnet.public-1.id,
    aws_subnet.public-2.id
  ]

  cross_zone_load_balancing   = true

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }

}

resource "aws_autoscaling_group" "ami-1" {
  name = "${aws_launch_configuration.ami-1.name}-asg"

  min_size             = 1
  desired_capacity     = 2
  max_size             = 4
  
  health_check_type    = "ELB"
  load_balancers = [
    aws_elb.chirag-sg.id
  ]

  launch_configuration = aws_launch_configuration.ami-1.name

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  vpc_zone_identifier  = [
    aws_subnet.public-1.id,
    aws_subnet.public-2.id
  ]

  # Required to redeploy without an outage.
  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "web"
    propagate_at_launch = true
  }

}

