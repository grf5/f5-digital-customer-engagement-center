###############
# VPC Section #
###############

# VPCs

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

locals {
  awsAz1 = var.awsAz1 != null ? var.awsAz1 : data.aws_availability_zones.available.names[0]
  awsAz2 = var.awsAz2 != null ? var.awsAz1 : data.aws_availability_zones.available.names[1]
}


# Subnets

resource "aws_subnet" "subnetPubAz1" {
  vpc_id            = var.vpcId
  cidr_block        = var.subnetPubAz1Cidr
  availability_zone = local.awsAz1

  tags = {
    Name  = "${var.projectPrefix}-subnetPubAz1-${var.buildSuffix}"
    Owner = var.resourceOwner
  }
}

resource "aws_subnet" "subnetPubAz2" {
  vpc_id            = var.vpcId
  cidr_block        = var.subnetPubAz2Cidr
  availability_zone = local.awsAz2

  tags = {
    Name  = "${var.projectPrefix}-subnetPubAz2-${var.buildSuffix}"
    Owner = var.resourceOwner
  }
}

resource "aws_subnet" "subnetGwlbeAz1" {
  count = var.createGwlbEndpoint ? 1 : 0
  vpc_id            = var.vpcId
  cidr_block        = var.subnetGwlbeAz1
  availability_zone = local.awsAz1

  tags = {
    Name  = "${var.projectPrefix}-subnetGwlbeAz1-${var.buildSuffix}"
    Owner = var.resourceOwner
  }
}

resource "aws_subnet" "subnetGwlbeAz2" {
  count = var.createGwlbEndpoint ? 1 : 0
  vpc_id            = var.vpcId
  cidr_block        = var.subnetGwlbeAz2
  availability_zone = local.awsAz2

  tags = {
    Name  = "${var.projectPrefix}-subnetGwlbeAz2-${var.buildSuffix}"
    Owner = var.resourceOwner
  }
}



##################GWLB#################

resource "aws_lb" "gwlb" {
  internal           = false
  load_balancer_type = "gateway"
  subnets            = [aws_subnet.subnetPubAz1.id, aws_subnet.subnetPubAz2.id]

  tags = {
    Name  = "${var.projectPrefix}-gwlb-${var.buildSuffix}"
    Owner = var.resourceOwner
  }
}

resource "aws_lb_target_group" "bigipTargetGroup" {
  port        = 6081
  protocol    = "GENEVE"
  target_type = "ip"
  vpc_id      = var.vpcId

  health_check {
    protocol = "HTTP"
    path     = "/"
    port     = 80
    matcher  = "200-399"
  }
  tags = {
    Name  = "${var.projectPrefix}-bigipTargetGroup-${var.buildSuffix}"
    Owner = var.resourceOwner
  }
}

resource "aws_lb_target_group_attachment" "bigipTargetGroupAttachmentAz1" {
  target_group_arn = aws_lb_target_group.bigipTargetGroup.arn
  target_id        = aws_instance.GeneveProxyAz1.private_ip
}

#resource "aws_lb_target_group_attachment" "bigipTargetGroupAttachmentAz2" {
#  target_group_arn = aws_lb_target_group.bigipTargetGroup.arn
#  target_id        = aws_instance.GeneveProxyAz2.private_ip
#}

resource "aws_vpc_endpoint_service" "gwlbEndpointService" {
  acceptance_required        = false
  gateway_load_balancer_arns = [aws_lb.gwlb.arn]
}

resource "aws_lb_listener" "gwlbListener" {
  load_balancer_arn = aws_lb.gwlb.id

  default_action {
    target_group_arn = aws_lb_target_group.bigipTargetGroup.id
    type             = "forward"
  }
}

resource "aws_vpc_endpoint" "vpcGwlbeAz1" {
  count = var.createGwlbEndpoint ? 1 : 0
  service_name      = aws_vpc_endpoint_service.gwlbEndpointService.service_name
  subnet_ids        = [aws_subnet.subnetGwlbeAz1[0].id]
  vpc_endpoint_type = "GatewayLoadBalancer"
  vpc_id            = var.vpcId
}

resource "aws_vpc_endpoint" "vpcGwlbeAz2" {
  count = var.createGwlbEndpoint ? 1 : 0
  service_name      = aws_vpc_endpoint_service.gwlbEndpointService.service_name
  subnet_ids        = [aws_subnet.subnetGwlbeAz2[0].id]
  vpc_endpoint_type = "GatewayLoadBalancer"
  vpc_id            = var.vpcId
}

##########BIGIP################
#
#
# Create random password for BIG-IP
#
resource "aws_iam_role" "main" {
  name               = "${var.projectPrefix}-iam-role-${var.buildSuffix}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "BigIpPolicy" {
  //name = "aws-iam-role-policy-${module.utils.env_prefix}"
  role   = aws_iam_role.main.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Action": [
            "ec2:DescribeInstances",
            "ec2:DescribeInstanceStatus",
            "ec2:DescribeAddresses",
            "ec2:AssociateAddress",
            "ec2:DisassociateAddress",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DescribeNetworkInterfaceAttribute",
            "ec2:DescribeRouteTables",
            "ec2:ReplaceRoute",
            "ec2:CreateRoute",
            "ec2:assignprivateipaddresses",
            "sts:AssumeRole",
            "s3:ListAllMyBuckets"
        ],
        "Resource": [
            "*"
        ],
        "Effect": "Allow"
    },
    {
        "Effect": "Allow",
        "Action": [
            "secretsmanager:GetResourcePolicy",
            "secretsmanager:GetSecretValue",
            "secretsmanager:PutSecretValue",
            "secretsmanager:DescribeSecret",
            "secretsmanager:ListSecretVersionIds",
            "secretsmanager:UpdateSecretVersionStage"
        ],
        "Resource": [
            "arn:aws:secretsmanager:${var.awsRegion}:${data.aws_caller_identity.current.account_id}:secret:*"
        ]
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "${var.projectPrefix}-iam-profile-${var.buildSuffix}"
  role = aws_iam_role.main.id
}

module "mgmt-network-security-group" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "${var.projectPrefix}-mgmt-nsg-${var.buildSuffix}"
  description = "Security group for BIG-IP Management"
  vpc_id      = var.vpcId

  ingress_cidr_blocks = var.allowedMgmtIps
  ingress_rules       = ["http-80-tcp", "https-443-tcp", "https-8443-tcp", "ssh-tcp"]
  ingress_with_cidr_blocks = [
    {
      from_port   = 6081
      to_port     = 6081
      protocol    = "udp"
      description = "Geneve for GWLB"
      cidr_blocks = "0.0.0.0/0"
    }
  ]
  # Allow ec2 instances outbound Internet connectivity
  egress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules       = ["all-all"]

}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# bash script template
data "template_file" "onboard" {
  template = file("${path.module}/files/onboard.sh")
  vars = {
    repositories = var.repositories
  }
}

data "template_cloudinit_config" "GeneveProxy" {
  gzip          = true
  base64_encode = true

  # Main cloud-config configuration file.
  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content      = file("${path.module}/files/cloud-config-base.yaml")
  }
  part {
    content_type = "text/x-shellscript"
    content      = data.template_file.onboard.rendered
  }

}

resource "aws_instance" "GeneveProxyAz1" {
  ami                         = data.aws_ami.ubuntu.id
  user_data                   = data.template_cloudinit_config.GeneveProxy.rendered
  instance_type               = "t3.large"
  subnet_id                   = aws_subnet.subnetPubAz1.id
  vpc_security_group_ids      = [module.mgmt-network-security-group.this_security_group_id]
  key_name                    = var.keyName
  associate_public_ip_address = true

  tags = {
    Name  = "${var.projectPrefix}-GeneveProxyAz1-${var.buildSuffix}"
    Owner = var.resourceOwner
  }
}

resource "aws_instance" "GeneveProxyAz2" {
  ami                         = data.aws_ami.ubuntu.id
  user_data                   = data.template_cloudinit_config.GeneveProxy.rendered
  instance_type               = "t3.large"
  subnet_id                   = aws_subnet.subnetPubAz2.id
  vpc_security_group_ids      = [module.mgmt-network-security-group.this_security_group_id]
  key_name                    = var.keyName
  associate_public_ip_address = true

  tags = {
    Name  = "${var.projectPrefix}-GeneveProxyAz2-${var.buildSuffix}"
    Owner = var.resourceOwner
  }
}