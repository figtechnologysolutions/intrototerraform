terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }
  }
}

variable "aws_region" {
  type        = string
  description = "The name of the AWS region in which to deploy the resources"
}
variable "base_cidr_block" {
  type        = string
  description = "The private IP address range to be assigned to the VPC. Should be at minimum a /16 address range."
  default     = "10.0.0.0/16"
}
variable "aws_profile_name" {
  type        = string
  description = "The name of the AWS CLI profile to connect with."
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile_name
}

resource "aws_vpc" "terraform_demo" {
  cidr_block = var.base_cidr_block
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "az_subnet" {
  count             = length(data.aws_availability_zones.available.names)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = aws_vpc.terraform_demo.id
  cidr_block        = cidrsubnet(aws_vpc.terraform_demo.cidr_block, 4, count.index + 1)
}

resource "aws_subnet" "public_subnet" {
  availability_zone = data.aws_availability_zones.available.names[0]
  vpc_id            = aws_vpc.terraform_demo.id
  cidr_block        = cidrsubnet(aws_vpc.terraform_demo.cidr_block, 4, length(aws_subnet.az_subnet.*.id) + 1)
}
resource "aws_internet_gateway" "inet_gw" {
  vpc_id = aws_vpc.terraform_demo.id
}
resource "aws_route_table" "inet_gateway_route_table" {
  vpc_id = aws_vpc.terraform_demo.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.inet_gw.id
  }
}
resource "aws_route_table_association" "public_subnet_route_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.inet_gateway_route_table.id
}
resource "aws_eip" "nat_gateway" {
  domain = "vpc"
}
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.public_subnet.id
}
resource "aws_route_table" "private_subnet_route_table" {
  vpc_id = aws_vpc.terraform_demo.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gateway.id
  }
}
locals {
  private_subnet_ids = aws_subnet.az_subnet.*.id
}
resource "aws_route_table_association" "private_subnet_route_association" {
  count          = length(local.private_subnet_ids)
  subnet_id      = local.private_subnet_ids[count.index]
  route_table_id = aws_route_table.private_subnet_route_table.id
}

resource "aws_security_group" "management_hosts" {
  name        = "management_ssh_to_vpc"
  description = "Allows all management hosts SSH access across the VPC"
  vpc_id      = aws_vpc.terraform_demo.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    self        = false
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "tls_private_key" "terraformdemo" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "management_key" {
  key_name   = "TerraformDemoKey"
  public_key = tls_private_key.terraformdemo.public_key_openssh
}

module "front_end_compute" {
  source              = "./compute_stack"
  label               = "front-end"
  management_sg_id    = aws_security_group.management_hosts.id
  ingress_ports       = toset(["80"])
  vpc_id              = aws_vpc.terraform_demo.id
  vpc_base_cidr_block = var.base_cidr_block
  subnet_ids          = aws_subnet.az_subnet.*.id
  desired_capacity    = length(data.aws_availability_zones.available.names)
  max_size            = 2 * (length(data.aws_availability_zones.available.names))
  min_size            = length(data.aws_availability_zones.available.names)
  ssh_key_name        = aws_key_pair.management_key.key_name
}

module "back_end_compute" {
  source              = "./compute_stack"
  label               = "back-end"
  management_sg_id    = aws_security_group.management_hosts.id
  ingress_ports       = toset(["5672"])
  vpc_id              = aws_vpc.terraform_demo.id
  vpc_base_cidr_block = var.base_cidr_block
  subnet_ids          = aws_subnet.az_subnet.*.id
  desired_capacity    = length(data.aws_availability_zones.available.names)
  max_size            = 2 * (length(data.aws_availability_zones.available.names))
  min_size            = length(data.aws_availability_zones.available.names)
  ssh_key_name        = aws_key_pair.management_key.key_name
}

module "management_host" {
  source               = "./management_host"
  management_subnet_id = aws_subnet.public_subnet.id
  management_sg_id     = aws_security_group.management_hosts.id
  ssh_key_name         = aws_key_pair.management_key.key_name
}
