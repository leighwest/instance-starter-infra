terraform {
  backend "s3" {
    bucket       = "instance-starter-infra-tfstate"
    key          = "iam/terraform.tfstate"
    region       = "ap-southeast-4"
    use_lockfile = true
  }
}