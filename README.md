# Network Operating Systems 2020 Course

This repository is the final project for the course Network Operating Systems, winter semester 2020.

It includes terraform scripts for automating the deployment process on the cloud environment (in this case on Azure cloud) as well as a guide (as part of this README) on how to configure the servers as required by the course assignment.

## Terraform setup

The Terraform files found in this repository create the following resources in a resource group named **Network-Operating-Systems** on Azure cloud:
- A VNet with address space 172.16.32.0/24
- Two subnets on the VNet space:
  - A subnet with address prefix of 172.16.32.0/27 in which the domain controller (DNS/AD server) will reside **-> DC subnet**
  - A subnet with address prefix of 172.16.32.32/27 in which the ftp/mail server and the client server will reside **-> VM subnet**
- Two network security groups (one for each subnet):
  - An NSG that allows inbound RDP traffic from the terraform host to the DC subnet
  - An NSG that allows inbound SSH traffic from the terraform host to the VM subnet
- One Windows 2019 Datacenter virtual machine sized Standard B2s for the domain controller server
- Two Linux (Ubuntu 18.04-LTS) virtual machines sized Standard B1s for the ftp/mail server and the client server
- Three public IP addresses, one for each VM
- Three network interface cards, one for each VM:
  - NIC for the DC server, with private IP association in the DC subnet and one public IP address
  - NIC for the ftp/mail server, with private IP association in the VM subnet and one public IP address
  - NIC for the client server, with private IP association in the DC subnet and one public IP address

Before starting with terraform commands, create a new resource group named **Network-Operating-Systems** in Azure and a service principal (SPN for short) and give it "Contributor" access on the resource group scope. Refer to [this link](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal) if you need further instructions.

To execute the scripts, clone this repository, cd into the directory and run ``terraform init``. Make sure you have [Terraform downloaded](https://www.terraform.io/downloads.html) and a **variables.tfvars** file with the required variable values created (check [variables.tf](https://github.com/amilovanovikj/Network-Operating-Systems/blob/main/variables.tf) for more info). Next execute ``terraform apply --var-file="variables.tfvars"`` and enter "yes" when promted for confirmation. This will spin up the whole environment in a couple of minutes.

In order to have access to cloud resources, execute the Terraform commands from the same host that will RDP/SSH into the VMs. This is due to the way Terraform is set up to query http://ipv4.icanhazip.com for the public IP address of the host executing Terraform, and whitelisting this IP address on the RDP/SSH NSG rules.

***