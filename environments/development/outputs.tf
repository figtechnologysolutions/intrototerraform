output "ssh_private_key_pem" {
  value     = module.aws_stack.ssh_private_key_pem
  sensitive = true
}
output "ssh_public_key_pem" {
  value = module.aws_stack.ssh_public_key_pem
}
output "management_public_ip" {
  value = module.aws_stack.management_public_ip
}
output "frontend_elb_dns_name" {
  value = module.aws_stack.frontend_elb_dns_name
}
output "backend_elb_dns_name" {
  value = module.aws_stack.backend_elb_dns_name
}
