provider "aws" {
  region = "us-west-2"
}

data "terraform_remote_state" "vpcs" {
  backend = "local"

  config = {
    path = "../vpcs/terraform.tfstate"
  }
}

locals {
  securityVpcId            = data.terraform_remote_state.vpcs.outputs.securityVpc.vpc_id
  securityPrivateSubnets   = data.terraform_remote_state.vpcs.outputs.securityVpc.private_subnets
  spoke10VpcId             = data.terraform_remote_state.vpcs.outputs.spoke10Vpc.vpc_id
  spoke20IntraSubnets    = data.terraform_remote_state.vpcs.outputs.spoke10Vpc.intra_subnets  
}

# See Notes in README.md for explanation regarding using data-sources and computed values


module "tgw" {
  source = "terraform-aws-modules/transit-gateway/aws"
  version = "1.4.0"

  name            = "${var.projectPrefix}-tgw-${random_id.buildSuffix.hex}"
  amazon_side_asn = 64532

  enable_auto_accept_shared_attachments = true # When "true" there is no need for RAM resources if using multiple AWS accounts

  vpc_attachments = {
    securityVpc = {
      vpc_id                                          = local.securityVpcId      # module.vpc1.vpc_id
      subnet_ids                                      = local.securityPrivateSubnets   # module.vpc1.private_subnets
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
      vpc_id     = local.spoke10VpcId      # module.vpc2.vpc_id
      subnet_ids = local.spoke20IntraSubnets # module.vpc2.private_subnets

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
