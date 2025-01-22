#main.tf
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "devopsProjectRG"
  location = "East US" # Choose your preferred region
}

#1.3 Create a Resource Group

resource "azurerm_resource_group" "rg" {
  name     = "devopsProjectRG"
  location = "East US" # Choose your preferred region
}


#1.4 Create a Virtual Network and Subnet

resource "azurerm_virtual_network" "vnet" {
  name                = "devopsVNet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "devopsSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

#1.5 Create a Network Security Group (NSG)

resource "azurerm_network_security_group" "nsg" {
  name                = "devopsNSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# 1.6 Configure Firewall Rules
# Allow SSH Access Only from Your IP

resource "azurerm_network_security_rule" "ssh_rule" {
  name                        = "AllowSSH"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefixes     = ["148.252.159.187/32"]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}


#Allow HTTP/HTTPS Access from Anywhere

resource "azurerm_network_security_rule" "http_rule" {
  name                        = "AllowHTTP"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefixes     = ["*"]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

#1.7 Create a Network Interface

resource "azurerm_network_interface" "nic" {
  name                = "devopsNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

#1.8 Create a Public IP

resource "azurerm_public_ip" "public_ip" {
  name                = "devopsPublicIP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

#1.9 Associate NSG with Subnet

resource "azurerm_subnet_network_security_group_association" "subnet_nsg" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 1.10 Create the Virtual Machine

resource "azurerm_linux_virtual_machine" "vm" {
  name                = "devopsVM"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s" # Choose appropriate VM size
  admin_username      = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub") # Ensure this points to your public SSH key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}



#1.13 Create Azure Kubernetes Service (AKS)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "devopsAKS"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "devopsAKS"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }
}

# Grant AKS Access to ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.identity.principal_id
}

# 1.14 Configure Azure Monitor for VM
# Create Log Analytics Workspace

resource "azurerm_log_analytics_workspace" "law" {
  name                = "devopsLAW"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

#Enable Diagnostics on VM
resource "azurerm_monitor_diagnostic_setting" "vm_diagnostic" {
  name               = "vmDiagnosticSetting"
  target_resource_id = azurerm_linux_virtual_machine.vm.id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  metrics {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }
}

#Create Action Group for Alerting
resource "azurerm_monitor_action_group" "ag" {
  name                = "devopsActionGroup"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "devopsAG"

  email_receiver {
    name                   = "Admin"
    email_address          = "admin@example.com" # Replace with your email
    use_common_alert_schema = true
  }
}

#Create Alert Rule for CPU Usage

resource "azurerm_monitor_metric_alert" "cpu_alert" {
  name                = "HighCPUUsage"
  resource_group_name = azurerm_resource_group.rg.name
  severity            = 3
  description         = "Alert when CPU usage exceeds 80%"
  frequency           = "PT1M"
  window_size         = "PT5M"
  scopes              = [azurerm_linux_virtual_machine.vm.id]

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.ag.id
  }
}


#2.2 Use Terraform to Run the Startup Script

resource "azurerm_linux_virtual_machine_extension" "custom_script" {
  name                 = "InstallDocker"
  virtual_machine_id   = azurerm_linux_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

  settings = <<SETTINGS
    {
      "fileUris": ["${path.module}/install_docker.sh"],
      "commandToExecute": "sh install_docker.sh"
    }
  SETTINGS
# 3.1 Enable System-Assigned Managed Identity for the VM
# Add to your VM resource:
}
identity {
  type = "SystemAssigned"
}

# 3.2 Grant Access to Azure Blob Storage and Azure Container Registry
# 3.2.1 Create Azure Container Registry (ACR)

resource "azurerm_container_registry" "acr" {
  name                = "devopsACR"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

#Assign Roles to VM's Managed Identity
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_virtual_machine.vm.identity[0].principal_id
}

resource "azurerm_storage_account" "storage" {
  name                     = "devopsstorageacct"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_role_assignment" "storage_blob_reader" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_virtual_machine.vm.identity[0].principal_id
}
