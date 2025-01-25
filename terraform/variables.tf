
# variables.tf

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure Region"
  type        = string
}

variable "vnet_name" {
  description = "Name of the Virtual Network"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_name" {
  description = "Name of the Subnet"
  type        = string
}

variable "subnet_prefixes" {
  description = "Address prefixes for the Subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "nsg_name" {
  description = "Name of the Network Security Group"
  type        = string
}

variable "my_ip_address" {
  description = "My public IP address for SSH access (e.g., '203.0.113.0/32')"
  type        = string
}

variable "vm_name" {
  description = "Name of the Virtual Machine"
  type        = string
}

variable "vm_size" {
  description = "Size of the Virtual Machine"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Admin username for the VM"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Path to your SSH public key (e.g., '~/.ssh/id_rsa.pub')"
  type        = string
}

variable "public_ip_name" {
  description = "Name of the Public IP"
  type        = string
}

variable "nic_name" {
  description = "Name of the Network Interface"
  type        = string
}

# variable "docker_install_script_path" {
#   description = "Path to the Docker install script"
#   type        = string
#   default     = "${path.module}/install_docker.sh"
# }

variable "acr_name" {
  description = "Name of the Azure Container Registry"
  type        = string
}

variable "aks_cluster_name" {
  description = "Name of the Azure Kubernetes Service cluster"
  type        = string
}

variable "aks_node_count" {
  description = "Number of nodes in the AKS cluster"
  type        = number
  default     = 1
}

variable "aks_node_size" {
  description = "Size of the nodes in the AKS cluster"
  type        = string
  default     = "Standard_DS2_v2"
}

variable "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  type        = string
}

variable "alert_email_address" {
  description = "Email address for alert notifications"
  type        = string
}

variable "storage_account_name" {
  description = "Name of the Storage Account"
  type        = string
}