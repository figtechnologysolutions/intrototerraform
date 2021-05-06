output "public_ip" {
  value = aws_eip.management_host.public_ip
}
