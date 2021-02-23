# output "workspaceManagementAddress" {
#   # Result is a map from instance id to private IP address, such as:
#   #  {"i-1234" = "192.168.1.2", "i-5678" = "192.168.1.5"}
#   value = {
#     for instance in aws_instance.workstation:
#     instance.id => "ssh@${aws_instance.workstation.public_ip}"
#   }
# }
output "workspaceManagementAddress" {
  value = var.associateEIP ? aws_instance.workstation.public_ip : aws_instance.workstation.private_ip
}
