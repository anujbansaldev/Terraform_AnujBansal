data "aws_ssm_parameter" "amazon_linux_2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_ec2_instance_type" "selected" {
  instance_type = var.instance_type
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_route_table" "selected" {
  route_table_id = "rtb-01367dbdc5e276f01"
}

data "aws_key_pair" "selected" {
  key_name = var.key_name
}

locals {
  subnet_has_public_internet_route = anytrue([
    for route in data.aws_route_table.selected.routes :
    try(route.cidr_block == "0.0.0.0/0", false) &&
    startswith(try(route.gateway_id, ""), "igw-")
  ])
}

resource "aws_security_group" "backend" {
  name        = "terraform-assignment-part-2-v2-backend-sg"
  description = "SSH and private Flask access for Task 2 v2 backend"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "SSH from the configured trusted CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_ssh_cidr]
  }

  ingress {
    description     = "Flask API from the Task 2 v2 frontend security group"
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.frontend.id]
  }

  egress {
    description = "Outbound access for package installation and application traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "frontend" {
  name        = "terraform-assignment-part-2-v2-frontend-sg"
  description = "SSH and Express access for Task 2 v2 frontend"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "SSH from the configured trusted CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_ssh_cidr]
  }

  ingress {
    description = "Express frontend from the configured client CIDR"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.client_cidr]
  }

  egress {
    description = "Outbound access for package installation and backend requests"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "backend" {
  ami                         = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type               = var.instance_type
  key_name                    = data.aws_key_pair.selected.key_name
  subnet_id                   = data.aws_subnet.selected.id
  vpc_security_group_ids      = [aws_security_group.backend.id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/backend-user-data.sh", {
    application_source_url = var.application_source_url
    application_source_ref = var.application_source_ref
    gunicorn_version       = var.gunicorn_version
  })

  tags = {
    Name = "terraform-assignment-part-2-v2-backend"
  }

  lifecycle {
    precondition {
      condition     = data.aws_subnet.selected.vpc_id == data.aws_vpc.selected.id
      error_message = "subnet_id must belong to vpc_id."
    }

    precondition {
      condition     = local.subnet_has_public_internet_route
      error_message = "subnet_id must have a 0.0.0.0/0 route through an internet gateway."
    }

    precondition {
      condition     = contains(data.aws_ec2_instance_type.selected.supported_architectures, "x86_64")
      error_message = "instance_type must support x86_64 for the selected Amazon Linux 2023 AMI."
    }
  }
}

resource "aws_instance" "frontend" {
  ami                         = data.aws_ssm_parameter.amazon_linux_2023_ami.value
  instance_type               = var.instance_type
  key_name                    = data.aws_key_pair.selected.key_name
  subnet_id                   = data.aws_subnet.selected.id
  vpc_security_group_ids      = [aws_security_group.frontend.id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/frontend-user-data.sh", {
    application_source_url = var.application_source_url
    application_source_ref = var.application_source_ref
    backend_private_ip     = aws_instance.backend.private_ip
  })

  tags = {
    Name = "terraform-assignment-part-2-v2-frontend"
  }

  lifecycle {
    precondition {
      condition     = data.aws_subnet.selected.vpc_id == data.aws_vpc.selected.id
      error_message = "subnet_id must belong to vpc_id."
    }

    precondition {
      condition     = local.subnet_has_public_internet_route
      error_message = "subnet_id must have a 0.0.0.0/0 route through an internet gateway."
    }

    precondition {
      condition     = contains(data.aws_ec2_instance_type.selected.supported_architectures, "x86_64")
      error_message = "instance_type must support x86_64 for the selected Amazon Linux 2023 AMI."
    }
  }
}
