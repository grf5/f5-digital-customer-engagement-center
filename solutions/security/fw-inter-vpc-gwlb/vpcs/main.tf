provider "aws" {
  region = var.awsRegion
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  awsAz1 = var.awsAz1 != null ? var.awsAz1 : data.aws_availability_zones.available.names[0]
  awsAz2 = var.awsAz2 != null ? var.awsAz1 : data.aws_availability_zones.available.names[1]
}

resource "aws_ec2_transit_gateway" "tgw" {
  description                     = "Transit Gateway"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  tags                            = {
    Name                          = "${var.projectPrefix}-tgw-${random_id.buildSuffix.hex}"
    Owner                         = var.resourceOwner
  }
}

resource "aws_ec2_transit_gateway_route_table" "spokeRt" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags               = {
    Name             = "${var.projectPrefix}-securityVpc-${random_id.buildSuffix.hex}"
    Owner            = var.resourceOwner
  }
  depends_on = [aws_ec2_transit_gateway.tgw]
}
resource "aws_ec2_transit_gateway_route" "spokeDefaultRoute" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.securityVpcTgwAttachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokeRt.id
}
resource "aws_ec2_transit_gateway_route_table" "securityRt" {
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  tags               = {
    Name             = "${var.projectPrefix}-securityRt-${random_id.buildSuffix.hex}"
    Owner            = var.resourceOwner
  }
  depends_on = [aws_ec2_transit_gateway.tgw]
}

resource "aws_ec2_transit_gateway_route_table_propagation" "spoke10RtbAssociation" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke10VpcTgwAttachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.securityRt.id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "spoke20RtbAssociation" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke20VpcTgwAttachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.securityRt.id
}

#Security VPC 
module "securityVpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.0"

  name = "${var.projectPrefix}-securityVpc-${random_id.buildSuffix.hex}"

  cidr = "10.1.0.0/16"

  azs              = [local.awsAz1, local.awsAz2]
  public_subnets   = ["10.1.10.0/24", "10.1.110.0/24", "10.1.1.0/24", "10.1.101.0/24"]
  #using database subnets as it is the only one that doesn't create its own routing table. see https://github.com/terraform-aws-modules/terraform-aws-vpc/issues/588
  database_subnets    = ["10.1.20.0/24", "10.1.120.0/24", "10.1.21.0/24", "10.1.121.0/24"]
  create_database_subnet_group = false
  create_database_subnet_route_table = true
}
resource "aws_default_route_table" "securityVpcDefaultRtb" {
  default_route_table_id = module.securityVpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = module.securityVpc.igw_id
  }
  route {
    cidr_block = "10.0.0.0/8"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }
  depends_on = [aws_ec2_transit_gateway.tgw]  
}

resource "aws_ec2_transit_gateway_vpc_attachment" "securityVpcTgwAttachment" {
  subnet_ids         = [module.securityVpc.database_subnets[0] , module.securityVpc.database_subnets[1]]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = module.securityVpc.vpc_id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags               = {
    Name             = "${var.projectPrefix}-securityVpcTgwAttachment-${random_id.buildSuffix.hex}"
    Owner            = var.resourceOwner
  }
  depends_on = [aws_ec2_transit_gateway.tgw]
}

resource "aws_ec2_transit_gateway_route_table_association" "securityVpcRtAssociation" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.securityVpcTgwAttachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.securityRt.id
}

#Spoke10 VPC 
module "spoke10Vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.0"

  name = "${var.projectPrefix}-spoke10Vpc-${random_id.buildSuffix.hex}"

  cidr = "10.10.0.0/16"
  azs              = [local.awsAz1, local.awsAz2]
  database_subnets    = ["10.10.20.0/24", "10.10.120.0/24"]
  create_database_subnet_group = false
  create_database_subnet_route_table = true

}

resource "aws_route" "spoke10VpcDatabaseRtb" {
  route_table_id            = module.spoke10Vpc.database_route_table_ids[0]
  destination_cidr_block    = "0.0.0.0/0"
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  depends_on = [aws_ec2_transit_gateway.tgw]
}
resource "aws_default_route_table" "spoke10VpcDefaultRtb" {
  default_route_table_id = module.spoke10Vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }
  depends_on = [aws_ec2_transit_gateway.tgw]
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke10VpcTgwAttachment" {
  subnet_ids         = [module.spoke10Vpc.database_subnets[0] , module.spoke10Vpc.database_subnets[1]]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = module.spoke10Vpc.vpc_id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags               = {
    Name             = "${var.projectPrefix}-spoke10VpcTgwAttachment-${random_id.buildSuffix.hex}"
    Owner            = var.resourceOwner
  }
  depends_on = [aws_ec2_transit_gateway.tgw]
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke10RtAssociation" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke10VpcTgwAttachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokeRt.id
}

#Spoke20 VPC 
module "spoke20Vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 2.0"

  name = "${var.projectPrefix}-spoke20Vpc-${random_id.buildSuffix.hex}"

  cidr = "10.20.0.0/16"

  azs              = [local.awsAz1, local.awsAz2]
  database_subnets    = ["10.20.20.0/24", "10.20.120.0/24"]
  create_database_subnet_group = false
  create_database_subnet_route_table = true

}

resource "aws_route" "spoke20VpcDatabaseRtb" {
  route_table_id            = module.spoke20Vpc.database_route_table_ids[0]
  destination_cidr_block    = "0.0.0.0/0"
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  depends_on = [aws_ec2_transit_gateway.tgw]
}
resource "aws_default_route_table" "spoke20VpcDefaultRtb" {
  default_route_table_id = module.spoke20Vpc.default_route_table_id
  route {
    cidr_block = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  }
  depends_on = [aws_ec2_transit_gateway.tgw]
}

resource "aws_ec2_transit_gateway_vpc_attachment" "spoke20VpcTgwAttachment" {
  subnet_ids         = [module.spoke20Vpc.database_subnets[0] , module.spoke20Vpc.database_subnets[1]]
  transit_gateway_id = aws_ec2_transit_gateway.tgw.id
  vpc_id             = module.spoke20Vpc.vpc_id
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false
  tags               = {
    Name             = "${var.projectPrefix}-spoke20VpcTgwAttachment-${random_id.buildSuffix.hex}"
    Owner            = var.resourceOwner
  }
  depends_on = [aws_ec2_transit_gateway.tgw]
}

resource "aws_ec2_transit_gateway_route_table_association" "spoke20RtAssociation" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.spoke20VpcTgwAttachment.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.spokeRt.id
}


#GWLB and BIGIPs 

resource "aws_key_pair" "deployer" {
  key_name   = "${var.projectPrefix}-key-${random_id.buildSuffix.hex}"
  public_key = var.sshPublicKey
}

module "gwlb-bigip" {
  source              = "../../../../modules/aws/terraform/gwlb-bigip"
  projectPrefix       = var.projectPrefix
  resourceOwner       = var.resourceOwner
  keyName             = aws_key_pair.deployer.id
  buildSuffix         = random_id.buildSuffix.hex
  instanceCount       = 1
  vpcId               = module.securityVpc.vpc_id
  subnetPubAz1Cidr    = "10.1.52.0/24"
  subnetPubAz2Cidr    = "10.1.152.0/24"
  subnetGwlbeAz1      = "10.1.54.0/24"
  subnetGwlbeAz2      = "10.1.154.0/24"
  createGwlbEndpoint  = true
}



###############OUTPUT

output "securityVpc" {
  value = module.securityVpc
}

output "spoke10Vpc" {
  value = module.spoke10Vpc
}

output "spoke20Vpc" {
  value = module.spoke20Vpc
}