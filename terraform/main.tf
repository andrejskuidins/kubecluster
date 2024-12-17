# main.tf
terraform {
  backend "s3" {
    bucket         = "ec2-testing-state-bucket-for-kube-project"
    key            = "terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"
  }
}

provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      Name        = "ec2-testing"
      region      = "eu"
      solution    = "1nce-connect"
      environment = "dev"
      component   = "kubemajik"
      owner       = "andrejs.kuidins"
    }
  }
}

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

# Rest of the VPC and EC2 configuration remains the same
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "eu-central-1a"

  tags = {
    Name = "main-subnet"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "main-rt"
  }
}

resource "aws_route_table_association" "main" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.main.id
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
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
    Name = "allow_ssh"
  }
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

resource "aws_key_pair" "generated_key" {
  key_name   = "terraform-key-pair-aku"
  public_key = file("~/.ssh/terraform-key-pair.pub")
}

# Create IAM role for EC2 instances
resource "aws_iam_role" "ssm_role" {
  name = "SSMInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "SSMInstanceRole"
  }
}

# Attach SSM policy to role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create instance profile
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "SSMInstanceProfile"
  role = aws_iam_role.ssm_role.name
}

# Modify the security group to allow SSM traffic
resource "aws_security_group_rule" "allow_ssm" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.allow_ssh.id
  description       = "Allow SSM HTTPS outbound"
}

# Add additional security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.allow_ssh.id]
  }

  tags = {
    Name = "vpc-endpoints-sg"
  }
}

# Modify VPC endpoints to use the new security group
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-central-1.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.main.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-central-1.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.main.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.eu-central-1.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.main.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# Add S3 VPC endpoint (Gateway type)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.eu-central-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.main.id]
}

# Modify the EC2 instance resource to use the key pair
resource "aws_instance" "kube_master" {
  ami                     = data.aws_ami.ubuntu.id
  instance_type           = "c7a.large"
  subnet_id               = aws_subnet.main.id
  key_name                = aws_key_pair.generated_key.key_name
  iam_instance_profile    = aws_iam_instance_profile.ssm_profile.name
  disable_api_termination = true

  vpc_security_group_ids = [
    aws_security_group.allow_ssh.id,
    aws_security_group.kubernetes_sg.id
  ]

  root_block_device {
    volume_size = 20    # Size in GB
    volume_type = "gp3" # Recommended volume type
  }

  user_data = <<-EOF
            #!/bin/bash
            apt-get update
            apt-get install -y snapd
            snap install amazon-ssm-agent --classic
            systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
            systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
            EOF

  # Make sure we wait for user data to complete
  user_data_replace_on_change = true

  tags = {
    Name = "andrej-aws-test-1"
  }
}

# Modify the EC2 instance resource to use the key pair
resource "aws_instance" "kube" {
  count                   = 1
  ami                     = data.aws_ami.ubuntu.id
  instance_type           = "c7a.medium"
  subnet_id               = aws_subnet.main.id
  key_name                = aws_key_pair.generated_key.key_name
  iam_instance_profile    = aws_iam_instance_profile.ssm_profile.name
  disable_api_termination = true

  vpc_security_group_ids = [
    aws_security_group.allow_ssh.id,
    aws_security_group.kubernetes_sg.id
  ]

  root_block_device {
    volume_size = 20    # Size in GB
    volume_type = "gp3" # Recommended volume type
  }

  user_data = <<-EOF
            #!/bin/bash
            apt-get update
            apt-get install -y snapd
            snap install amazon-ssm-agent --classic
            systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
            systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
            EOF

  # Make sure we wait for user data to complete
  user_data_replace_on_change = true

  tags = {
    Name = "andrej-aws-test-${count.index + 2}"
  }
}

# Replace the existing kubernetes_sg resource with this simplified version
resource "aws_security_group" "kubernetes_sg" {
  name        = "kubernetes-sg"
  description = "Allow all internal traffic between Kubernetes nodes"
  vpc_id      = aws_vpc.main.id

  # Allow all internal traffic within the subnet
  ingress {
    description = "All internal traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.0.1.0/24"] # This matches your subnet CIDR
  }

  # Allow outbound traffic (typically needed for updates, package installation)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kubernetes-sg"
  }
}

output "master_public_ips" {
  value = aws_instance.kube_master.public_ip
}

output "instance_public_ips" {
  value = aws_instance.kube[*].public_ip
}
