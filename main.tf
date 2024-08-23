# Web App Server
resource "aws_instance" "web_server" {
  ami             = data.aws_ami.latest_amazon_linux.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.web-server-sg.name]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello, from HashiCorp!</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "web-server"
  }
}

resource "aws_security_group" "web-server-sg" {
  name        = "web-server-sg1"
  description = "Allow HTTP from Anywhere"

  ingress {
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
    Name = "web-server-sg"
  }
}

# Data block to fetch the latest Amazon Linux 2 AMI
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}
