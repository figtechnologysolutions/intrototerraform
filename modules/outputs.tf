output "ssh_private_key_pem" {
  value = tls_private_key.terraformdemo.private_key_pem
}
output "ssh_public_key_pem" {
  value = tls_private_key.terraformdemo.public_key_pem
}
output "management_public_ip" {
  value = module.management_host.public_ip
}
output "frontend_elb_dns_name" {
  value = module.front_end_compute.elb_dns_name
}
output "backend_elb_dns_name" {
  value = module.back_end_compute.elb_dns_name
}
