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
data "terraform_remote_state" "securityVpc" {
  backend = "local"

  config = {
    path = "..."
  }
}

data "aws_subnet_ids" "this" {
  vpc_id = data.aws_vpc.default.id
}

module "tgw" {
  source = "terraform-aws-modules/transit-gateway/aws"
  version = "1.4.0"

  name            = "${var.projectPrefix}-tgw-${random_id.buildSuffix.hex}"
  amazon_side_asn = 64532

  enable_auto_accept_shared_attachments = true # When "true" there is no need for RAM resources if using multiple AWS accounts

  vpc_attachments = {
    securityVpc = {
      vpc_id                                          = module.securityVpc.vpc_id      # module.vpc1.vpc_id
      subnet_ids                                      = module.securityVpc.private_subnets   # module.vpc1.private_subnets
      dns_support                                     = true
      #transit_gateway_default_route_table_association = false
      #transit_gateway_default_route_table_propagation = false
      #      transit_gateway_route_table_id = "tgw-rtb-073a181ee589b360f"

      tgw_routes = [
        {
          destination_cidr_block = "30.0.0.0/16"
        },
        {
          blackhole              = true
          destination_cidr_block = "0.0.0.0/0"
        }
      ]
    },
    spoke10Vpc = {
      vpc_id     = module.spoke10Vpc.vpc_id      # module.vpc2.vpc_id
      subnet_ids = module.spoke10Vpc.private_subnets # module.vpc2.private_subnets

      tgw_routes = [
        {
          destination_cidr_block = "50.0.0.0/16"
        },
        {
          blackhole              = true
          destination_cidr_block = "10.10.10.10/32"
        }
      ]
    },
  }

  ram_allow_external_principals = true
  ram_principals                = [307990089504]

  tags = {
    Purpose = "tgw-complete-example"
  }
}

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