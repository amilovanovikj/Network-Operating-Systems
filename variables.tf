variable "client_id" {
  type        = string
  sensitive   = true
  description = "The application (client) ID of the SPN used for resource provisioning with Terraform"
}
variable "client_secret" {
  type        = string
  sensitive   = true
  description = "The client secret of the SPN used for resource provisioning with Terraform"
}
variable "tenant_id" {
  type        = string
  sensitive   = true
  description = "The AAD tenant where the SPN used for resource provisioning with Terraform is located in"
}
variable "subscription_id" {
  type        = string
  sensitive   = true
  description = "The ID of the Azure subscription where Terraform will provision resources"
}
variable "ssh_key_client" {
  type        = string
  sensitive   = true
  description = "The SSH key for connecting to the Linux client machine"
}
variable "ssh_key_mail" {
  type        = string
  sensitive   = true
  description = "The SSH key for connecting to the FTP/Mail Linux server"
}
variable linux_username {
  type        = string
  sensitive   = true
  description = "The username for the Linux VMs"
}
variable windows_username {
  type        = string
  sensitive   = true
  description = "The admin username for the Windows server"
}
variable windows_password {
  type        = string
  sensitive   = true
  description = "The admin password for the Windows server"
}