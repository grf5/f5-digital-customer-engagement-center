locals {
  vpcs = {
    "vpcGwlb" = aws_vpc.vpcGwlb.id
  }
  subnetsAz1 = {
    "vpcGwlbSubPubA" = aws_subnet.vpcGwlbSubPubA.id
  }
  subnetsAz2 = {
    "vpcGwlbSubPubB" = aws_subnet.vpcGwlbSubPubB.id
  }
}

output "vpcs" {
  value = local.vpcs
}

output "subnetsAz1" {
  value = local.subnetsAz1
}

output "subnetsAz2" {
  value = local.subnetsAz2
}

output "geneveProxyAz1Ip" {
  value = aws_instance.GeneveProxyAz1.public_ip
}
output "geneveProxyAz2Ip" {
  value = aws_instance.GeneveProxyAz2.public_ip
}
output "gwlbEndpointService" {
  value = aws_vpc_endpoint_service.gwlbEndpointService.service_name
}
output "gwlbeAz1" {
  description = "Id of the GWLB endpoint in AZ1"
  value = aws_vpc_endpoint.vpcGwlbeAz1[0].id
}
output "gwlbeAz2" {
  description = "Id of the GWLB endpoint in AZ2"
  value = aws_vpc_endpoint.vpcGwlbeAz2[0].id
}
output "subnetGwlbeAz1" {
  value = aws_subnet.subnetGwlbeAz1[0].id
}
output "subnetGwlbeAz2" {
  value = aws_subnet.subnetGwlbeAz2[0].id
}