terraform {
  backend "s3" {
    bucket       = "notcreated"
    key          = "state/development"
    region       = "ap-southeast-2"
    profile      = "terraform"
    use_lockfile = true
  }
}
module "aws_stack" {
  source           = "../../modules/"
  aws_region       = "ap-southeast-2"
  base_cidr_block  = "10.0.0.0/16"
  aws_profile_name = "terraform"
}
