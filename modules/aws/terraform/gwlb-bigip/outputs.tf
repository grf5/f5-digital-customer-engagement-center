locals {
  subnetsAz1 = {
    "vpcGwlbSubPubA" = aws_subnet.subnetPubAz1.id
  }
  subnetsAz2 = {
    "vpcGwlbSubPubB" = aws_subnet.subnetPubAz2.id
  }
}

output "subnetGwlbeAz1" {
  value = aws_subnet.subnetGwlbeAz1.id
}
output "subnetGwlbeAz2" {
  value = aws_subnet.subnetGwlbeAz2.id
}
output "subnetsAz2" {
  value = local.subnetsAz2
}
output "subnetsAz1" {
  value = local.subnetsAz1
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
