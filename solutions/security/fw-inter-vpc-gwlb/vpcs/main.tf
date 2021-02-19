provider "aws" {
  region = "us-west-2"
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  awsAz1 = var.awsAz1 != null ? var.awsAz1 : data.aws_availability_zones.available.names[0]
  awsAz2 = var.awsAz2 != null ? var.awsAz1 : data.aws_availability_zones.available.names[1]
}

# See Notes in README.md for explanation regarding using data-sources and computed values


module "securityVpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.0"

  name = "${var.projectPrefix}-securityVpc-${random_id.buildSuffix.hex}"

  cidr = "10.1.0.0/16"

  azs              = [local.awsAz1, local.awsAz2]
  public_subnets   = ["10.1.10.0/24", "10.1.110.0/24", "10.1.1.0/24", "10.1.101.0/24"]
  private_subnets  = ["10.1.20.0/24", "10.1.120.0/24"]

}

module "spoke10Vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.0"

  name = "${var.projectPrefix}-spoke10Vpc-${random_id.buildSuffix.hex}"

  cidr = "10.10.0.0/16"

  azs              = [local.awsAz1, local.awsAz2]
  intra_subnets  = ["10.10.20.0/24", "10.10.120.0/24"]

}

module "spoke20Vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.0"

  name = "${var.projectPrefix}-spoke20Vpc-${random_id.buildSuffix.hex}"

  cidr = "10.20.0.0/16"

  azs              = [local.awsAz1, local.awsAz2]
  intra_subnets  = ["10.20.20.0/24", "10.20.120.0/24"]

}

output "securityVpc" {
  value = module.securityVpc
}

output "spoke10Vpc" {
  value = module.spoke10Vpc
}

output "spoke20Vpc" {
  value = module.spoke20Vpc
}