resource "random_id" "buildSuffix" {
  byte_length = 2
}
variable "projectPrefix" {
  description = "projectPrefix name for tagging"
  default     = "fw-inter-vpc"
}
variable "resourceOwner" {
  default = "elsa"
}