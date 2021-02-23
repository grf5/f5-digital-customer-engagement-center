variable "vpcId" {
  description = "ID of the vpc where resources will get created"
  default     = null
}
variable "projectPrefix" {
  description = "projectPrefix name to use for tags"
  default     = "f5-dcec"
}
variable "resourceOwner" {
  description = "owner of the deployment, for tagging purposes"
  default     = "f5-dcec"
}
variable "buildSuffix" {
  description = "random build suffix for tagging"
  default     = "f5-dcec"
}
variable "bigipPassword" {
  description = "password for the bigip admin account"
  default     = null
}
variable "awsAz1" {
  description = "will use a dynamic az if left empty"
  default     = null
}
variable "awsAz2" {
  description = "will use a dynamic az if left empty"
  default     = null
}
variable "awsRegion" {
  default = "us-west-2"
}
variable "keyName" {
  default = null
}
variable "allowedMgmtIps" {
  default = ["0.0.0.0/0"]
}
variable "instanceCount" {
  default = 1
}
variable "vpcCidr" {
  default = "10.252.0.0/16"
}
variable "subnetPubAz1Cidr" {
  default = "10.252.10.0/24"
}
variable "subnetPubAz2Cidr" {
  default = "10.252.110.0/24"
}
variable "subnetGwlbeAz1" {
  default = "10.252.54.0/24"
}
variable "subnetGwlbeAz2" {
  default = "10.252.154.0/24"
}
variable "createGwlbEndpoint" {
  default = false
  type    = bool
  description = "Controls the creation of gwlb endpoints in the provided vpc, if true creates subnets and endpoints"
}
variable "repositories" {
  description = "comma seperated list of git repositories to clone"
  default     = "https://github.com/vinnie357/aws-tf-workspace.git,https://github.com/f5devcentral/terraform-aws-f5-sca.git"
}
