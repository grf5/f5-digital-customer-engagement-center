provider "aws" {
  region = var.awsRegion
}

data "terraform_remote_state" "vpcs" {
  backend = "local"

  config = {
    path = "../vpcs/terraform.tfstate"
  }
}

locals {

  vpcs = {

  securityVpcData = {
    vpcId    = data.terraform_remote_state.vpcs.outputs.internetVpc
    subnetId = data.terraform_remote_state.vpcs.outputs.subnetInternetJumphostAz1
  }
  spoke10VpcData = {
    vpcId    = data.terraform_remote_state.vpcs.outputs.spoke10Vpc.vpc_id
    subnetId = data.terraform_remote_state.vpcs.outputs.spoke10Vpc.database_subnets[0] 
  }
  spoke20VpcData = {
    vpcId    = data.terraform_remote_state.vpcs.outputs.spoke20Vpc.vpc_id
    subnetId = data.terraform_remote_state.vpcs.outputs.spoke20Vpc.database_subnets[0]
  }

  }

}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.resourceOwner}-${var.projectPrefix}"
  public_key = var.sshPublicKey
}

resource "aws_security_group" "secGroupWorkstation" {
  for_each    = local.vpcs
  name        = "secGroupWorkstation"
  description = "Jumphost workstation security group"
  vpc_id      = each.value["vpcId"]

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5800
    to_port     = 5800
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name  = "${var.projectPrefix}-secGroupWorkstation"
    Owner = var.resourceOwner
  }
}


module "jumphost" {
  for_each    = local.vpcs
  source        = "../../../../modules/aws/terraform/workstation/"
  projectPrefix = var.projectPrefix
  resourceOwner = var.resourceOwner
  vpc           = each.value["vpcId"]
  keyName       = aws_key_pair.deployer.id
  mgmtSubnet    = each.value["subnetId"]
  securityGroup = aws_security_group.secGroupWorkstation[each.key].id
  associateEIP  = each.key == "securityVpcData" ? true : false
}