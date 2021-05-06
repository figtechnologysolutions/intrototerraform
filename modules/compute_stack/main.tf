variable "label" {
  type        = string
  description = "Prefix to identify resources in this module. Also applied as a 'Name' tag"
}

variable "management_sg_id" {
  type        = string
  description = "Resource ID for the Management server security group. Created resources will permit SSH from this SG."
}
variable "ingress_ports" {
  type        = set(string)
  description = "List of ports which will be allowed from the internal load balancer to the created Autoscaling Group."
}

variable "vpc_id" {
  type        = string
  description = "Resource ID for the VPC in which these resources should be created."
}

variable "vpc_base_cidr_block" {
  type        = string
  description = "The CIDR block for the entire VPC to allow access to the internal load balancer for the compute resources"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs to load balance across."
}

variable "ssh_key_name" {
  type        = string
  description = "The AWS Key name which will provide SSH access to this VM."
}

variable "desired_capacity" {
  type        = number
  description = "The desired number of VMs to create in the Autoscaling group"
}
variable "max_size" {
  type        = number
  description = "The maximum size of our Autoscaling group"
}
variable "min_size" {
  type        = number
  description = "The minimum size of our Autoscaling group"
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
  owners = ["099720109477"] # Canonical AMI Owner ID
}

resource "aws_security_group" "compute_security_group" {
  name        = "${var.label}_security_group"
  description = "Security group for ${var.label} compute resources"
  vpc_id      = var.vpc_id
}
resource "aws_security_group_rule" "compute_internet_access" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.compute_security_group.id
}
resource "aws_security_group_rule" "ssh_management_to_compute" {
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  source_security_group_id = var.management_sg_id
  security_group_id        = aws_security_group.compute_security_group.id
}

resource "aws_security_group" "lb_security_group" {
  name        = "${var.label}_lb_security_group"
  description = "Security group for ${var.label} Load Balancer"
  vpc_id      = var.vpc_id
}
resource "aws_security_group_rule" "vpc_to_lb_ingress" {
  for_each          = var.ingress_ports
  type              = "ingress"
  from_port         = tonumber(each.key)
  to_port           = tonumber(each.key)
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_base_cidr_block]
  security_group_id = aws_security_group.lb_security_group.id
}

resource "aws_security_group_rule" "lb_to_compute_ingress" {
  for_each                 = var.ingress_ports
  type                     = "ingress"
  from_port                = tonumber(each.key)
  to_port                  = tonumber(each.key)
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb_security_group.id
  security_group_id        = aws_security_group.compute_security_group.id
}

resource "aws_elb" "elastic_load_balancer" {
  name            = "${var.label}-elb"
  internal        = true
  security_groups = [aws_security_group.lb_security_group.id]
  subnets         = var.subnet_ids
  tags = {
    Name = var.label
  }
  dynamic "listener" {
    for_each = var.ingress_ports
    content {
      instance_port     = tonumber(listener.key)
      instance_protocol = "tcp"
      lb_port           = tonumber(listener.key)
      lb_protocol       = "tcp"
    }
  }
}

resource "aws_launch_template" "compute_launch_template" {
  name_prefix            = "${var.label}_"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.compute_security_group.id]
}

resource "aws_autoscaling_group" "compute_scale_group" {
  desired_capacity = var.desired_capacity
  max_size         = var.max_size
  min_size         = var.min_size
  launch_template {
    id      = aws_launch_template.compute_launch_template.id
    version = "$Default"
  }
  load_balancers      = [aws_elb.elastic_load_balancer.id]
  vpc_zone_identifier = var.subnet_ids
}
