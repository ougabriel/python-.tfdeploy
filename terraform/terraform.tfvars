# terraform.tfvars

resource_group_name            = "devopsProjectRG"
location                       = "East US"
vnet_name                      = "devopsVNet"
subnet_name                    = "devopsSubnet"
nsg_name                       = "devopsNSG"
your_ip_address                = "148.252.159.187/32" # Replace with your public IP
vm_name                        = "devopsVM"
admin_username                 = "azureuser"
ssh_public_key_path            = "~/.ssh/id_rsa.pub"  # Ensure this points to your public SSH key
public_ip_name                 = "devopsPublicIP"
nic_name                       = "devopsNIC"
docker_install_script_path     = "${path.module}/install_docker.sh"
acr_name                       = "devopsACR"
aks_cluster_name               = "devopsAKS"
log_analytics_workspace_name   = "devopsLAW"
alert_email_address            = "admin@example.com"  # Replace with your email
storage_account_name           = "devopsstorageacct"