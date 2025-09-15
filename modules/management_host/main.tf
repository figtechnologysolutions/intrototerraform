variable "management_subnet_id" {
  type        = string
  description = "The Resource ID for the public subnet into which our management host will be placed."
}
variable "management_sg_id" {
  type        = string
  description = "The Resource ID for the Security Group into which we want to place the management host."
}
variable "ssh_key_name" {
  type        = string
  description = "The AWS Key name which will provide SSH access to this VM."
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
resource "aws_instance" "management_host" {
  instance_type   = "t3.micro"
  ami             = data.aws_ami.ubuntu.id
  subnet_id       = var.management_subnet_id
  security_groups = [var.management_sg_id]
  key_name        = var.ssh_key_name
}
resource "aws_eip" "management_host" {
  instance = aws_instance.management_host.id
  domain   = "vpc"
}
