#!/bin/bash
terraform -chdir=vpcs init
terraform -chdir=tgw init
terraform -chdir=vpcs plan -var-file=../admin.auto.tfvars  
read -p "Press enter to continue"
terraform -chdir=vpcs apply -var-file=../admin.auto.tfvars --auto-approve
terraform -chdir=tgw apply -var-file=../admin.auto.tfvars --auto-approve
# apply

